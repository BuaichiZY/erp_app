package sex.erp.android;

import android.app.Activity;
import android.graphics.Color;
import android.net.Uri;
import android.os.*;
import android.webkit.*;
import android.widget.*;
import org.json.JSONObject;

/** The web component is limited to the site-required Cloudflare verification. */
final class InlineVerification extends LinearLayout {
    interface State { void changed(boolean ready,String message); }
    private final WebView widget;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final State state;
    private final boolean required;
    private String document;
    private String token="";
    private boolean closed;
    InlineVerification(Activity activity,String key,String userAgent,boolean dark,State state){
        this(activity,key,userAgent,dark,"login",state);
    }
    InlineVerification(Activity activity,String key,String userAgent,boolean dark,String action,State state){
        super(activity);this.state=state;required=!key.isEmpty();setOrientation(VERTICAL);
        if(!required){widget=null;document="";state.changed(true,"");return;}
        widget=new WebView(activity);widget.setBackgroundColor(Color.TRANSPARENT);
        addView(widget,new LayoutParams(-1,Math.round(116*getResources().getDisplayMetrics().density)));
        WebSettings settings=widget.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(true);settings.setUserAgentString(userAgent);settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        CookieManager.getInstance().setAcceptThirdPartyCookies(widget,true);
        widget.addJavascriptInterface(new Object(){
            @JavascriptInterface public void result(String value){ui.post(()->{if(closed)return;if(value!=null&&value.length()>20&&value.length()<10000){token=value;state.changed(true,UiStrings.t("安全验证已完成"));}});}
            @JavascriptInterface public void failed(String code){ui.post(()->{if(!closed){token="";state.changed(false,UiStrings.t("验证未完成，请点击重试"));}});}
            @JavascriptInterface public void expired(){ui.post(()->{if(!closed){token="";state.changed(false,UiStrings.t("验证已过期，请重新验证"));}});}
        },"NativeVerification");
        widget.setWebViewClient(new WebViewClient(){
            @Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){Uri u=request.getUrl();return !("about".equals(u.getScheme())||("https".equals(u.getScheme())&&("erp.sex".equals(u.getHost())||"challenges.cloudflare.com".equals(u.getHost()))));}
            @Override public void onReceivedError(WebView view,WebResourceRequest request,WebResourceError error){if(request.isForMainFrame()&&!closed){token="";state.changed(false,UiStrings.t("验证加载失败，请检查网络后重试"));}}
            @Override public boolean onRenderProcessGone(WebView view,RenderProcessGoneDetail detail){close();state.changed(false,UiStrings.t("验证控件已关闭，请重新进入登录页"));return true;}
        });
        String html="<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'></head><body style='margin:4px 0;background:#101115;display:flex;justify-content:center'><div id='verify'></div><script>var widgetId;function ready(){widgetId=turnstile.render('#verify',{sitekey:"+JSONObject.quote(key)+",action:'login',language:'zh-cn',theme:'dark',size:'flexible',callback:function(t){NativeVerification.result(t)},'error-callback':function(c){NativeVerification.failed(c)},'expired-callback':function(){NativeVerification.expired();turnstile.reset(widgetId)}})}function resetVerification(){if(window.turnstile&&widgetId!==undefined)turnstile.reset(widgetId)}</script><script src='https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit&onload=ready' async defer></script></body></html>";
        html=html.replace("language:'zh-cn'","language:"+JSONObject.quote(UiStrings.language().equals("zh-Hans")?"zh-cn":UiStrings.language().equals("zh-Hant")?"zh-tw":UiStrings.language()));
        html=html.replace("action:'login'","action:"+JSONObject.quote(action));
        document=dark?html:html.replace("theme:'dark'","theme:'light'").replace("background:#101115","background:#f4f5f7");state.changed(false,UiStrings.t("请在下方完成安全验证"));load();
    }
    boolean ready(){return !closed&&(!required||!token.isEmpty());}
    String token(){return token;}
    void appearance(boolean dark){if(widget==null||closed)return;document=document.replace("theme:'dark'","theme:'light'").replace("background:#101115","background:#f4f5f7");if(dark)document=document.replace("theme:'light'","theme:'dark'").replace("background:#f4f5f7","background:#101115");token="";state.changed(false,UiStrings.t("请在下方完成安全验证"));load();}
    private void load(){widget.loadDataWithBaseURL(NativeApi.ORIGIN+"/",document,"text/html","UTF-8",null);}
    void reset(){if(closed)return;token="";state.changed(!required,required?UiStrings.t("请重新完成安全验证"):"");if(widget!=null)widget.evaluateJavascript("(function(){if(window.turnstile&&widgetId!==undefined){resetVerification();return true;}return false;})()",result->{if(!closed&&!"true".equals(result))load();});}
    void close(){if(closed)return;closed=true;token="";ui.removeCallbacksAndMessages(null);if(widget!=null){removeView(widget);widget.removeJavascriptInterface("NativeVerification");widget.stopLoading();widget.destroy();}}
}
