package sex.erp.android;

import android.app.*;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.text.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;
import java.util.function.*;

/** Paginated comment threads and a native composer that survives read-only refreshes. */
final class PostDiscussion extends LinearLayout {
    private final Activity activity;
    private final NativeApi api;
    private ThemePalette palette;
    private final String postId;
    private final BooleanSupplier current;
    private final Supplier<JSONObject> session;
    private final Runnable login;
    private final Consumer<JSONObject> report;
    private final Consumer<NativeApi.Failure> failure;
    private final IntConsumer changed;
    private final LinkedHashMap<String,JSONObject> rows=new LinkedHashMap<>();
    private final Set<String> deleting=new HashSet<>();
    private final Set<String> loadedCursors=new HashSet<>();
    private final LinearLayout threads,composer;
    private final EditText input;
    private final TextView heading,replyLabel,counter;
    private final Button send,cancel,more;
    private String cursor="",replyId="",replyName="";
    private int generation,commentCount;
    private boolean loading,sending;
    PostDiscussion(Activity activity,NativeApi api,ThemePalette palette,String postId,int commentCount,BooleanSupplier current,Supplier<JSONObject> session,Runnable login,Consumer<JSONObject> report,Consumer<NativeApi.Failure> failure,IntConsumer changed){
        super(activity);this.activity=activity;this.api=api;this.palette=palette;this.postId=postId;this.commentCount=commentCount;this.current=current;this.session=session;this.login=login;this.report=report;this.failure=failure;this.changed=changed;setOrientation(VERTICAL);setPadding(dp(16),dp(16),dp(16),dp(16));setBackground(background(palette.surface,16));
        heading=label(UiStrings.t("评论"),16,palette.text);heading.setTypeface(null,android.graphics.Typeface.BOLD);add(heading);
        composer=column();replyLabel=label("",12,palette.muted);addTo(composer,replyLabel);input=new EditText(activity);input.setTextColor(palette.text);input.setHintTextColor(palette.muted);input.setTextSize(13);input.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_FLAG_MULTI_LINE);input.setMinLines(3);input.setGravity(Gravity.TOP);input.setHint(UiStrings.t("留下评论…"));input.setPadding(dp(10),dp(10),dp(10),dp(10));input.setBackground(background(palette.surface,12));addTo(composer,input);LinearLayout footer=row();counter=label("0 / 500",11,palette.muted);footer.addView(counter,new LayoutParams(0,-2,1));cancel=button(UiStrings.t("取消回复"),()->{replyId="";replyName="";update();});footer.addView(cancel,new LayoutParams(-2,dp(34)));send=button(UiStrings.t("发送"),this::send);LayoutParams lp=new LayoutParams(dp(64),dp(34));lp.leftMargin=dp(8);footer.addView(send,lp);composer.addView(footer);add(composer);
        input.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int a,int c,int f){}public void onTextChanged(CharSequence s,int a,int b,int c){}public void afterTextChanged(Editable e){update();}});
        threads=column();add(threads);more=button(UiStrings.t("加载更多评论"),()->load(false));update();
    }
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private LinearLayout column(){LinearLayout v=new LinearLayout(activity);v.setOrientation(VERTICAL);return v;}
    private LinearLayout row(){LinearLayout v=new LinearLayout(activity);v.setGravity(Gravity.CENTER_VERTICAL);return v;}
    private GradientDrawable background(int color,int radius){if(palette.pop)return new PopDrawable(color,dp(radius),palette.border,getResources().getDisplayMetrics().density);GradientDrawable bg=new GradientDrawable();bg.setColor(color);bg.setCornerRadius(dp(radius));bg.setStroke(dp(1),palette.border);return bg;}
    private TextView label(String text,int size,int color){TextView view=new TextView(activity);view.setText(text);view.setTextSize(size);view.setTextColor(color);return view;}
    private Button button(String text,Runnable click){Button b=new Button(activity);b.setText(text);b.setTextColor(palette.text);b.setTextSize(12);b.setAllCaps(false);b.setMinHeight(0);b.setMinimumHeight(0);b.setPadding(dp(10),0,dp(10),0);b.setBackground(background(palette.surface2,16));b.setStateListAnimator(null);b.setOnClickListener(v->click.run());return b;}
    private void add(View view){addTo(this,view);}
    private void addTo(LinearLayout parent,View view){LayoutParams lp=new LayoutParams(-1,-2);lp.bottomMargin=dp(10);parent.addView(view,lp);}
    private boolean allowed(){JSONObject me=session.get();if(me==null||"restricted".equals(me.optString("status")))return false;JSONArray limits=me.optJSONArray("featureLimits");if(limits!=null)for(int i=0;i<limits.length();i++)if("post".equals(limits.optString(i)))return false;return true;}
    private void update(){JSONObject me=session.get();heading.setText(UiStrings.t("评论")+(commentCount>0?"  "+commentCount:""));boolean can=allowed();input.setEnabled(can&&!sending);input.setHint(me==null?UiStrings.t("登录后发表评论"):can?(replyId.isEmpty()?UiStrings.t("留下评论…"):UiStrings.t("回复 ")+replyName):UiStrings.t("当前账号暂时无法评论"));replyLabel.setVisibility(replyId.isEmpty()?GONE:VISIBLE);replyLabel.setText(UiStrings.t("回复 ")+replyName);cancel.setVisibility(replyId.isEmpty()?GONE:VISIBLE);cancel.setEnabled(!sending);String draft=input.getText().toString();int length=draft.trim().codePointCount(0,draft.trim().length());counter.setText(length+" / 500");counter.setTextColor(length>500?palette.accent:palette.muted);send.setText(sending?UiStrings.t("发送中"):me==null?UiStrings.t("登录"):UiStrings.t("发送"));send.setTextColor(Color.WHITE);send.setBackground(background(palette.accent,16));send.setEnabled(!sending&&(me==null||can&&PostRules.canComment(draft)));send.setAlpha(send.isEnabled()?1:.5f);more.setVisibility(cursor.isEmpty()?GONE:VISIBLE);more.setEnabled(!loading);}
    void count(int value){commentCount=Math.max(0,value);update();}
    void refresh(){load(true);}
    private void load(boolean replace){if(!current.getAsBoolean()||!isAttachedToWindow()||sending)return;if(!replace&&(loading||cursor.isEmpty()||!loadedCursors.add(cursor)))return;final int expected=replace?++generation:generation;final String requestedCursor=cursor;if(replace)loadedCursors.clear();loading=true;more.setEnabled(false);if(replace&&rows.isEmpty()){threads.removeAllViews();threads.addView(label(UiStrings.t("正在加载评论…"),12,palette.muted));}api.call("GET","/posts/"+NativeApi.encode(postId)+"/comments"+(replace?"":"?cursor="+NativeApi.encode(requestedCursor)),null,(result,error)->{if(!current.getAsBoolean()||expected!=generation||!isAttachedToWindow())return;loading=false;if(error!=null){if(!replace)loadedCursors.remove(requestedCursor);if(rows.isEmpty())threads.removeAllViews();threads.addView(button(UiStrings.t("无法加载评论，点击重试"),replace?this::refresh:()->load(false)));update();failure.accept(error);return;}if(replace)rows.clear();JSONObject response=NativeApi.object(result);JSONArray items=response.optJSONArray("items");if(items!=null)for(int i=0;i<items.length();i++){JSONObject item=items.optJSONObject(i);if(item!=null)rows.put(item.optString("id"),item);}cursor=response.optString("nextCursor","");render();update();if(!cursor.isEmpty())post(()->load(false));});}
    private void render(){threads.removeAllViews();if(rows.isEmpty()){threads.addView(label(UiStrings.t("还没有评论，来说点什么吧。"),12,palette.muted));return;}for(JSONObject comment:rows.values()){addTo(threads,comment(comment,false));JSONArray replies=comment.optJSONArray("replies");if(replies!=null)for(int i=0;i<replies.length();i++){JSONObject reply=replies.optJSONObject(i);if(reply==null)continue;LinearLayout inset=column();inset.setPadding(dp(30),0,0,0);inset.addView(comment(reply,true));addTo(threads,inset);}View line=new View(activity);line.setBackgroundColor(palette.border);LayoutParams lp=new LayoutParams(-1,dp(1));lp.bottomMargin=dp(12);threads.addView(line,lp);}}
    private View comment(JSONObject comment,boolean reply){JSONObject author=comment.optJSONObject("author");if(author==null)author=new JSONObject();LinearLayout block=row();int size=reply?24:30;FrameLayout avatar=new FrameLayout(activity);avatar.setBackground(background(palette.surface2,size/2));avatar.setClipToOutline(true);AnimatedPhotoView image=new AnimatedPhotoView(activity);image.palette(palette);image.setScaleType(ImageView.ScaleType.CENTER_CROP);avatar.addView(image,new FrameLayout.LayoutParams(-1,-1));api.image(image,author.optJSONObject("avatar"),true);LayoutParams avatarLp=new LayoutParams(dp(size),dp(size));avatarLp.gravity=Gravity.TOP;block.addView(avatar,avatarLp);LinearLayout content=column();LayoutParams copyLp=new LayoutParams(0,-2,1);copyLp.leftMargin=dp(8);block.addView(content,copyLp);LinearLayout name=row();TextView title=label(author.optString("displayName",UiStrings.t("用户")),12,palette.text);title.setTypeface(null,android.graphics.Typeface.BOLD);name.addView(title,new LayoutParams(0,-2,1));name.addView(label(ChatPresentation.time(comment.optString("createdAt"),"MM-dd HH:mm"),10,palette.muted));addTo(content,name);TextView body=label(ProfileData.text(comment.opt("body")),13,palette.text);body.setTextIsSelectable(true);addTo(content,body);LinearLayout actions=row();Button respond=button(UiStrings.t("回复"),()->{replyId=comment.optString("id");replyName=title.getText().toString();update();input.requestFocus();((android.view.inputmethod.InputMethodManager)activity.getSystemService(android.content.Context.INPUT_METHOD_SERVICE)).showSoftInput(input,android.view.inputmethod.InputMethodManager.SHOW_IMPLICIT);});respond.setEnabled(allowed()&&!sending);actions.addView(respond,new LayoutParams(-2,dp(28)));JSONObject me=session.get();boolean mine=me!=null&&me.optString("id").equals(author.optString("id"));Button extra=button(mine?UiStrings.t("删除"):UiStrings.t("举报"),()->{if(session.get()==null){login.run();return;}if(mine)new SiteDialog.Builder(activity,palette).setMessage(UiStrings.t("删除这条评论？")).setNegativeButton(UiStrings.t("取消"),null).setPositiveButton(UiStrings.t("删除"),(d,w)->delete(comment)).show();else report.accept(comment);});LayoutParams extraLp=new LayoutParams(-2,dp(28));extraLp.leftMargin=dp(6);actions.addView(extra,extraLp);content.addView(actions);return block;}
    private void delete(JSONObject comment){if(!current.getAsBoolean()||!deleting.add(comment.optString("id")))return;api.call("DELETE","/posts/"+NativeApi.encode(postId)+"/comments/"+NativeApi.encode(comment.optString("id")),null,(result,error)->{if(!current.getAsBoolean()||!isAttachedToWindow())return;deleting.remove(comment.optString("id"));if(error!=null)failure.accept(error);else{commentCount=Math.max(0,commentCount-1);changed.accept(-1);if(comment.optString("id").equals(replyId)){replyId="";replyName="";}refresh();update();}});}
    private void send(){if(session.get()==null){login.run();return;}String body=input.getText().toString().trim();if(sending||!allowed()||!current.getAsBoolean()||!PostRules.canComment(body))return;JSONObject payload=NativeApi.json("body",body);if(!replyId.isEmpty())try{payload.put("replyTo",replyId);}catch(JSONException ignored){}sending=true;update();api.call("POST","/posts/"+NativeApi.encode(postId)+"/comments",payload,(result,error)->{if(!current.getAsBoolean()||!isAttachedToWindow())return;sending=false;if(error!=null){update();failure.accept(error);return;}input.setText("");replyId="";replyName="";commentCount++;changed.accept(1);update();refresh();});}
    void palette(ThemePalette value){palette=value;setBackground(background(value.surface,16));render();update();}
}
