package sex.erp.android;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;
import java.util.function.*;

/** Inline image reactions update independently of the card and its photo position. */
final class ProfileReactionBar extends LinearLayout {
    private final NativeApi api;
    private final JSONObject user;
    private final String kind,owner;
    private final JSONArray emojis;
    private final BooleanSupplier current;
    private final Supplier<String> userId;
    private final Runnable login,changed;
    private final Consumer<NativeApi.Failure> failure;
    private ThemePalette palette;
    private JSONArray reactions;
    private PopupWindow picker;
    private boolean busy;
    ProfileReactionBar(Context context,NativeApi api,ThemePalette palette,JSONObject user,JSONArray emojis,BooleanSupplier current,Supplier<String> userId,Runnable login,Runnable changed,Consumer<NativeApi.Failure> failure){
        this(context,api,palette,user,"profile",user.optString("id"),emojis,current,userId,login,changed,failure);
    }
    ProfileReactionBar(Context context,NativeApi api,ThemePalette palette,JSONObject user,String kind,String owner,JSONArray emojis,BooleanSupplier current,Supplier<String> userId,Runnable login,Runnable changed,Consumer<NativeApi.Failure> failure){
        super(context);setOrientation(VERTICAL);setGravity(Gravity.END);this.api=api;this.palette=palette;this.user=user;this.kind=kind;this.owner=owner;this.emojis=emojis;this.current=current;this.userId=userId;this.login=login;this.changed=changed;this.failure=failure;reactions=user.optJSONArray("reactions");if(reactions==null)reactions=new JSONArray();render();
    }
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    void palette(ThemePalette value){palette=value;if(picker!=null)picker.dismiss();render();}
    private Set<String> existing(boolean onlyMine){Set<String> values=new HashSet<>();for(int i=0;i<reactions.length();i++){JSONObject r=reactions.optJSONObject(i);if(r!=null&&(!onlyMine||r.optBoolean("mine")))values.add(r.optString("emoji"));}return values;}
    private TextView chip(String label,boolean mine){TextView text=new TextView(getContext());text.setText(label);text.setTextColor(Color.WHITE);text.setTextSize(11);text.setTypeface(null,android.graphics.Typeface.BOLD);text.setGravity(Gravity.CENTER);text.setPadding(dp(6),0,dp(6),0);GradientDrawable bg=new GradientDrawable();bg.setColor(mine?palette.accent:0x99000000);bg.setCornerRadius(dp(20));text.setBackground(bg);text.setEnabled(!busy);text.setAlpha(busy?.55f:1);return text;}
    private void render(){
        removeAllViews();LinearLayout line=null;int count=0;
        for(int i=0;i<Math.min(20,reactions.length());i++){JSONObject r=reactions.optJSONObject(i);if(r==null||r.optInt("count")<=0)continue;if(count%4==0){line=new LinearLayout(getContext());line.setGravity(Gravity.END);addView(line,new LayoutParams(-1,-2));}String emoji=r.optString("emoji");boolean mine=r.optBoolean("mine");TextView chip=chip(emoji+" "+r.optInt("count"),mine);chip.setContentDescription(emoji+"，"+r.optInt("count")+(mine?UiStrings.t("，点击撤回"):UiStrings.t("，点击加一")));chip.setOnClickListener(v->select(emoji,true));LayoutParams lp=new LayoutParams(-2,dp(26));lp.leftMargin=dp(3);lp.bottomMargin=dp(3);line.addView(chip,lp);count++;}
        if(!owner.equals(userId.get())){if(line==null||count%4==0){line=new LinearLayout(getContext());line.setGravity(Gravity.END);addView(line,new LayoutParams(-1,-2));}FrameLayout add=new FrameLayout(getContext());GradientDrawable bg=new GradientDrawable();bg.setColor(0x99000000);bg.setCornerRadius(dp(20));add.setBackground(bg);add.addView(new SiteIconView(getContext(),"reaction",Color.WHITE,false),new FrameLayout.LayoutParams(dp(17),dp(17),Gravity.CENTER));add.setEnabled(!busy);add.setAlpha(busy?.55f:1);add.setContentDescription(UiStrings.t("选择表情"));add.setOnClickListener(v->{if(userId.get().isEmpty()){login.run();return;}if(existing(true).size()>=ReactionRules.MAX_MINE){Toast.makeText(getContext(),UiStrings.t("最多添加 3 种表情，可点击已选表情撤回"),Toast.LENGTH_SHORT).show();return;}if(picker!=null&&picker.isShowing()){picker.dismiss();return;}picker=ReactionPickerPopup.show(getContext(),add,palette,emojis,existing(false),existing(true),emoji->select(emoji,false));});LayoutParams lp=new LayoutParams(dp(28),dp(28));lp.leftMargin=dp(3);lp.bottomMargin=dp(3);line.addView(add,lp);}
    }
    private void select(String emoji,boolean fromChip){
        if(busy||!current.getAsBoolean())return;if(userId.get().isEmpty()){login.run();return;}boolean mine=existing(true).contains(emoji);
        if(owner.equals(userId.get())){new android.app.AlertDialog.Builder(getContext()).setTitle(UiStrings.t("移除表情")).setMessage(UiStrings.t("移除自己内容上的全部 ")+emoji+UiStrings.t(" 表情？")).setNegativeButton(UiStrings.t("取消"),null).setPositiveButton(UiStrings.t("移除"),(d,w)->submit(emoji,true,true)).show();return;}
        String decision=fromChip&&mine?"remove":ReactionRules.pick(existing(false).contains(emoji),mine,existing(true).size(),reactions.length());
        if(decision.equals("none"))return;if(decision.equals("limit")||decision.equals("full")){Toast.makeText(getContext(),decision.equals("limit")?UiStrings.t("最多添加 3 种表情"):UiStrings.t("此名片的表情种类已满"),Toast.LENGTH_SHORT).show();return;}
        submit(emoji,decision.equals("remove"),false);
    }
    private void submit(String emoji,boolean remove,boolean own){
        if(busy||!current.getAsBoolean()||!isAttachedToWindow())return;busy=true;render();String path=("post".equals(kind)?"/posts/"+NativeApi.encode(user.optString("id")):(own?"/me":"/profiles/"+NativeApi.encode(user.optString("id"))))+"/reactions"+(remove?"?emoji="+NativeApi.encode(emoji):"");
        api.call(remove?"DELETE":"POST",path,remove?null:NativeApi.json("emoji",emoji),(r,e)->{if(!current.getAsBoolean()||!isAttachedToWindow())return;busy=false;if(e!=null){render();failure.accept(e);return;}JSONArray fresh=NativeApi.object(r).optJSONArray("reactions");if(fresh!=null){reactions=fresh;try{user.put("reactions",fresh);}catch(JSONException ignored){}}render();changed.run();});
    }
    @Override protected void onDetachedFromWindow(){if(picker!=null)picker.dismiss();super.onDetachedFromWindow();}
    @Override protected void onWindowVisibilityChanged(int visibility){super.onWindowVisibilityChanged(visibility);if(visibility!=VISIBLE&&picker!=null)picker.dismiss();}
}
