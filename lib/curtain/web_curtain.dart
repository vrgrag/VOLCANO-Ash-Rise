import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../bridge/insight.dart';
import '../core/constants.dart';
import '../relay/agent_client.dart';
import '../relay/alert_center.dart';
import '../relay/locker.dart';
import '../relay/reach_probe.dart';
import 'offline_curtain.dart';

// ============================================================
// WEB CURTAIN — immersive full-screen WebView (gray content)
// ============================================================
// Hosts the content link with: forged device UA, both orientations,
// immersive system UI, external-scheme hand-off, redirect-loop recovery,
// debounced connectivity guard, warm push link loading, native file
// uploads, third-party cookies, media autoplay, and safe-area / keyboard
// JS fixes.
// ============================================================

class WebCurtain extends StatefulWidget {
  const WebCurtain({
    super.key,
    required this.link,
    required this.locker,
    required this.alertCenter,
    required this.reachProbe,
  });

  final String link;
  final Locker locker;
  final AlertCenter alertCenter;
  final ReachProbe reachProbe;

  @override
  State<WebCurtain> createState() => _WebCurtainState();
}

class _WebCurtainState extends State<WebCurtain> with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _redirectRetries = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _offlineDebounce;

  // Clarity funnel state — the WebView DOM is not recorded by replay, so
  // these signals tell us whether the offer site was even reached and, if
  // not, why (see .cursor/rules/clarity_analytics.mdc §4).
  bool _offerReached = false;
  bool _pageHadError = false;

  static final RegExp _depositRx = RegExp(
      r'(deposit|cashier|top.?up|replenish|payment|checkout|wallet|пополн|депозит|касс|оплат|внести|платеж)',
      caseSensitive: false);
  static final RegExp _registerRx = RegExp(
      r'(sign.?up|regist|create.?account|onboarding|регистрац|зарегистр)',
      caseSensitive: false);
  static final RegExp _loginRx = RegExp(
      r'(sign.?in|log.?in|log.?on|/auth\b|authoriz|войти|вход|авториз)',
      caseSensitive: false);

  // [FINGERPRINT] Must match MainActivity.kt `channelName`.
  static const MethodChannel _uploadChannel = MethodChannel('ashrise/filepick');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    Insight.screen('web');
    Insight.event('web_open');
    _buildController();

    widget.alertCenter.onLink = (String link) {
      if (mounted) _web.loadRequest(Uri.parse(link));
    };

    // Debounced connectivity drop (700ms) absorbs VPN flicker
    // (gray_part_pitfalls.md §3) before swapping to the offline curtain.
    _connSub = widget.reachProbe.changes.listen((List<ConnectivityResult> r) {
      final bool allNone = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _offlineDebounce?.cancel();
        return;
      }
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(const Duration(milliseconds: 700), _openOffline);
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      Insight.event('web_foreground');
    } else if (state == AppLifecycleState.paused) {
      // Combined with `last_screen == web` this is the clearest drop-off
      // marker — user backgrounded the app on the offer.
      Insight.event('web_background');
    }
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agentClient.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..addJavaScriptChannel('AegisInsight',
          onMessageReceived: (JavaScriptMessage m) => _onWebSignal(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _pageHadError = false;
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _spinner = false);
          _redirectRetries = 0;
          _neutralizeSafeArea();
          _keyboardScrollFix();
          _installInsightProbe();
          _trackWebPage(url);
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          _pageHadError = true;
          final String d = err.description.toLowerCase();

          final String reason = _classifyWebError(err);
          final String failed = _lastMainFrame ?? widget.link;
          final String host = Uri.tryParse(failed)?.host ?? '';
          Insight.event('web_error');
          Insight.tag('web_error_reason', reason);
          Insight.tag(
              'web_last_error', '${err.errorCode}:${err.description}');
          if (host.isNotEmpty) Insight.tag('web_error_host', host);
          if (!_offerReached) {
            Insight.event('web_offer_unreachable');
            Insight.tag('offer_reached', 'false');
            Insight.tag('offer_unreachable_reason', reason);
          } else {
            Insight.event('web_error_after_load');
          }

          final bool loop = d.contains('too_many_redirects') ||
              d.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectRetries < 3) {
            _redirectRetries++;
            _web.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }

          // Cover the native WebView error page immediately with our
          // spinner (gray_part_pitfalls.md §4).
          if (mounted) setState(() => _spinner = true);

          final bool dnsOrDrop = d.contains('name_not_resolved') ||
              d.contains('internet_disconnected') ||
              d.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (dnsOrDrop) {
            _openOffline();
          } else {
            _guardOffline();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrame = req.url;
            return NavigationDecision.navigate;
          }
          // External-scheme hand-off (deposit/payment intent, tel:, mailto:...).
          Insight.event('web_external');
          Insight.tag('web_external_scheme', uri.scheme);
          _openExternally(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tuneAndroid();
    _web.loadRequest(Uri.parse(widget.link));
  }

  void _tuneAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _web.platform as AndroidWebViewController;

    a.setMediaPlaybackRequiresUserGesture(false);
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );
    a.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // Probe-then-show: for transient WebView load errors.
  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool online = await widget.reachProbe.isReachable();
    if (online) {
      if (mounted) setState(() => _spinner = false);
      return;
    }
    _openOffline();
  }

  void _openOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.link;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineCurtain(
          onRetryBuild: (_) => WebCurtain(
            link: current,
            locker: widget.locker,
            alertCenter: widget.alertCenter,
            reachProbe: widget.reachProbe,
          ),
        ),
      ),
    );
  }

  // Scrolls focused inputs above the keyboard. behavior:'auto' + a single
  // delayed pass to avoid fighting the keyboard animation (pitfalls §3).
  void _keyboardScrollFix() {
    _web.runJavaScript(r'''
(function(){
  if (window.__arKbFix) return; window.__arKbFix = true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement; if(!isField(el))return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect(); var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20||r.top<vp.offsetTop){el.scrollIntoView({behavior:'auto',block:'nearest'});}
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){ if(isField(e.target)) setTimeout(bring,350); });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height; if(h<prev) setTimeout(bring,120); prev=h;
    });
  }
})();
''');
  }

  // Neutralizes only the SITE's safe-area variables + known decorative top
  // spacers. Never zeroes padding/margin on html/body/#app/#root so the
  // partner site keeps its own horizontal gutters
  // (.cursor/rules/webview_safe_area_injection.mdc).
  void _neutralizeSafeArea() {
    _web.runJavaScript(r'''
(function(){
  if(window.__arSa) return; window.__arSa=true;
  var ID='__ar_sa';
  var CSS=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;'
    +'--safe-top:0px!important;--safe-bottom:0px!important;--safe-left:0px!important;--safe-right:0px!important;}'
    +'.gameview-mobile-header,.app-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}';
  function kbOpen(){ if(!window.visualViewport)return false; return window.visualViewport.height<window.innerHeight*0.75; }
  function apply(){
    if(kbOpen())return;
    var head=document.head||document.documentElement; if(!head)return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){ s=document.createElement('style'); s.id=ID; head.appendChild(s); }
    if(s.textContent!==CSS) s.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn]; history[fn]=function(){var r=o.apply(this,arguments); setTimeout(apply,80); setTimeout(apply,400); return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  void _trackWebPage(String url) {
    final Uri? uri = Uri.tryParse(url);
    Insight.screenName('web:${uri == null ? url : '${uri.host}${uri.path}'}');
    Insight.event('web_page');
    Insight.tag('web_last_url', url);
    if (!_offerReached && !_pageHadError) {
      _offerReached = true;
      Insight.event('web_offer_reached');
      Insight.tag('offer_reached', 'true');
      if (uri?.host != null) Insight.tag('offer_host', uri!.host);
    }
    if (_depositRx.hasMatch(url)) {
      Insight.event('web_cashier_page');
      Insight.tag('reached_cashier', 'true');
    }
    _trackAuthPage(url);
  }

  void _trackAuthPage(String url) {
    if (_registerRx.hasMatch(url)) {
      Insight.event('web_register_page');
      Insight.tag('reached_register', 'true');
    } else if (_loginRx.hasMatch(url)) {
      Insight.event('web_login_page');
      Insight.tag('reached_login', 'true');
    }
  }

  static String _classifyWebError(WebResourceError err) {
    final String d = err.description.toLowerCase();
    final int c = err.errorCode;
    if (d.contains('connection_refused') || d.contains('connection refused')) {
      return 'connection_refused';
    }
    if (d.contains('too_many_redirects') || d.contains('too many redirects')) {
      return 'redirect_loop';
    }
    if (d.contains('name_not_resolved') ||
        d.contains('address_unreachable') ||
        d.contains('unknownhost') ||
        c == -2) {
      return 'dns_unresolved';
    }
    if (d.contains('timed out') || d.contains('timeout') || c == -8) {
      return 'timeout';
    }
    if (d.contains('internet_disconnected') ||
        d.contains('network_changed') ||
        c == -6) {
      return 'no_network';
    }
    if (d.contains('connection_reset')) return 'connection_reset';
    if (d.contains('connection_closed') || d.contains('empty_response')) {
      return 'connection_closed';
    }
    if (d.contains('ssl') || d.contains('cert') || c == -11) return 'ssl_error';
    if (d.contains('blocked')) return 'blocked';
    return 'other';
  }

  // Idempotent JS probe — the WebView DOM is invisible to replay, so we
  // bridge SPA route changes, deposit/register/login clicks and auth form
  // submits back to native for Clarity events.
  void _installInsightProbe() {
    _web.runJavaScript(r'''
(function(){
  if (window.__aegisInsight) return; window.__aegisInsight = true;
  function send(t){ try { AegisInsight.postMessage(t); } catch(e){} }
  var DEP=/(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|пополн|депозит|касс|оплат|внести|вывод|платеж)/i;
  var REG=/(sign.?up|regist|create.?account|регистрац|зарегистр)/i;
  var LOG=/(sign.?in|log.?in|log.?on|войти|вход|авториз)/i;
  var lastPath='';
  function reportPath(){ var p=location.pathname+location.search; if(p!==lastPath){ lastPath=p; send('path:'+p);} }
  reportPath();
  ['pushState','replaceState'].forEach(function(fn){ var o=history[fn]; history[fn]=function(){ var r=o.apply(this,arguments); setTimeout(reportPath,60); return r; }; });
  window.addEventListener('popstate',function(){ setTimeout(reportPath,60); });
  document.addEventListener('click',function(e){
    try{ var el=e.target;
      for(var i=0;i<4&&el;i++){
        var t=((el.innerText||el.value||(el.getAttribute&&el.getAttribute('aria-label'))||'')+'').trim();
        if(t){ if(DEP.test(t)){send('deposit_click:'+t.slice(0,60));return;}
               if(REG.test(t)){send('register_click:'+t.slice(0,60));return;}
               if(LOG.test(t)){send('login_click:'+t.slice(0,60));return;} }
        el=el.parentElement;
      }
    }catch(x){}
  },true);
  document.addEventListener('submit',function(e){
    try{ var f=e.target;
      var pw=f.querySelectorAll?f.querySelectorAll('input[type="password"]'):[];
      var blob=((f.innerText||'')+' '+(f.getAttribute('action')||'')+' '+(f.className||''));
      var confirm=f.querySelector&&(f.querySelector('input[name*="confirm" i]')||f.querySelector('input[name*="repeat" i]'));
      if(pw&&pw.length>=2){send('auth_submit:register');return;}
      if(pw&&pw.length===1){ send('auth_submit:'+((confirm||REG.test(blob))?'register':'login')); return; }
      if(REG.test(blob)){send('auth_submit:register');return;}
      if(LOG.test(blob)){send('auth_submit:login');return;}
      send('form_submit');
    }catch(x){ send('form_submit'); }
  },true);
})();
''');
  }

  void _onWebSignal(String raw) {
    final int i = raw.indexOf(':');
    final String type = i < 0 ? raw : raw.substring(0, i);
    final String data = i < 0 ? '' : raw.substring(i + 1);
    switch (type) {
      case 'path':
        Insight.event('web_spa_route');
        Insight.tag('web_last_path', data);
        if (_depositRx.hasMatch(data)) {
          Insight.event('web_cashier_page');
          Insight.tag('reached_cashier', 'true');
        }
        _trackAuthPage(data);
        break;
      case 'deposit_click':
        Insight.event('web_deposit_click');
        Insight.tag('deposit_intent', 'true');
        if (data.isNotEmpty) Insight.tag('deposit_label', data);
        break;
      case 'register_click':
        Insight.event('web_register_click');
        Insight.tag('register_intent', 'true');
        break;
      case 'login_click':
        Insight.event('web_login_click');
        Insight.tag('login_intent', 'true');
        break;
      case 'auth_submit':
        if (data == 'register') {
          Insight.event('web_register_submit');
          Insight.tag('attempted_register', 'true');
        } else {
          Insight.event('web_login_submit');
          Insight.tag('attempted_login', 'true');
        }
        break;
      case 'form_submit':
        Insight.event('web_form_submit');
        break;
    }
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineDebounce?.cancel();
    _connSub?.cancel();
    widget.alertCenter.onLink = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Keep a safe zone around the camera cutout in BOTH orientations
            // (top in portrait, side in landscape). No bottom inset — the
            // keyboard is handled by the JS scroll fix.
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.emberOrange),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
