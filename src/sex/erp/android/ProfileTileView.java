package sex.erp.android;

import android.content.Context;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;
import java.util.function.Consumer;

/** Cover tiles keep the website's 3:4 grid ratio and 4:5 profile banner ratio. */
final class ProfileTileView extends FrameLayout {
    private final boolean large;
    private final DanmakuView danmaku;
    private final LinearLayout reactionTop;
    ProfileTileView(Context context,NativeApi api,ThemePalette palette,JSONObject user,String action,boolean large,Runnable open,Consumer<String> reaction){
        super(context);this.large=large;setBackground(large?topRounded(palette.image):background(palette.image,14));setClipToOutline(true);
        JSONObject cover=user.optJSONObject("cover");if(cover==null)cover=user.optJSONObject("avatar");
        AnimatedPhotoView image=new AnimatedPhotoView(context);image.palette(palette);if(cover!=null)image.focus((float)cover.optDouble("focusX",.5),(float)cover.optDouble("focusY",.5));addView(image,new LayoutParams(-1,-1));api.image(image,cover,true);
        if(cover==null||!"show".equals(cover.optString("view","show"))){TextView hidden=label(cover==null?UiStrings.t("暂无封面"):UiStrings.t("内容暂不可见"),12,palette.muted);hidden.setGravity(Gravity.CENTER);addView(hidden,new LayoutParams(-1,-1));}
        View shade=new View(context);shade.setBackground(new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,new int[]{0,0x18000000,0xe6000000}));LayoutParams shadeLp=new LayoutParams(-1,-1);addView(shade,shadeLp);
        LinearLayout top=new LinearLayout(context);reactionTop=top;top.setOrientation(LinearLayout.VERTICAL);top.setGravity(Gravity.END);top.setPadding(dp(6),dp(6),dp(6),0);JSONArray reactions=user.optJSONArray("reactions");int count=reactions==null?0:Math.min(reactions.length(),large?12:3);
        for(int start=0;start<count;start+=3){LinearLayout line=new LinearLayout(context);line.setGravity(Gravity.END);for(int i=start;i<Math.min(start+3,count);i++){JSONObject r=reactions.optJSONObject(i);if(r==null)continue;String emoji=r.optString("emoji");TextView chip=chip(emoji+" "+r.optInt("count"),large?11:10,r.optBoolean("mine")?palette.accent:0x80000000);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,dp(21));lp.leftMargin=dp(3);lp.bottomMargin=dp(3);line.addView(chip,lp);if(reaction!=null)chip.setOnClickListener(v->reaction.accept(emoji));}top.addView(line,new LinearLayout.LayoutParams(-1,-2));}addView(top,new LayoutParams(-1,-2,Gravity.TOP));
        LinearLayout overlay=new LinearLayout(context);overlay.setOrientation(LinearLayout.VERTICAL);overlay.setPadding(dp(large?16:10),dp(14),dp(large?16:10),dp(large?12:10));
        if(large){largeOverlay(overlay,api,palette,user);}else{
        JSONObject shine=user.optJSONObject("shine");LinearLayout ranks=new LinearLayout(context);if(shine!=null){if(shine.optInt("likes")>0)ranks.addView(chip("♥ "+(large?UiStrings.t("前 "):"")+shine.optInt("likes")+"%",large?12:10,0xffff63a7));if(shine.optInt("superlikes")>0){TextView rank=chip("★ "+(large?UiStrings.t("前 "):"")+shine.optInt("superlikes")+"%",large?12:10,0xffefa52c);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,-2);lp.leftMargin=dp(4);ranks.addView(rank,lp);}}if(ranks.getChildCount()>0){LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,-2);lp.bottomMargin=dp(5);overlay.addView(ranks,lp);}
LinearLayout nameLine=new LinearLayout(context);nameLine.setGravity(Gravity.CENTER_VERTICAL);TextView name=label(user.optString("displayName"),large?24:16,Color.WHITE);name.setTypeface(null,Typeface.BOLD);name.setSingleLine();name.setEllipsize(android.text.TextUtils.TruncateAt.END);nameLine.addView(name,new LinearLayout.LayoutParams(0,-2,1));JSONObject badges=user.optJSONObject("badges");if(badges!=null&&badges.optBoolean("vrcVerified")){TextView badge=chip("✓",large?13:11,0xff9650e7);badge.setContentDescription(UiStrings.t("VRChat 已验证"));nameLine.addView(badge,new LinearLayout.LayoutParams(-2,-2));}overlay.addView(nameLine);
TextView tagline=label(ProfileData.text(user,"tagline"),11,0xfff0f0f0);tagline.setSingleLine();tagline.setEllipsize(android.text.TextUtils.TruncateAt.END);overlay.addView(tagline);if(user.optInt("matchCount")>0)overlay.addView(label(UiStrings.t("♡ 已配对 ")+user.optInt("matchCount")+UiStrings.t(" 人"),10,Color.WHITE));if(user.optInt("mutualMatches")>0)overlay.addView(label(UiStrings.t("♧ 共同配对 ")+user.optInt("mutualMatches")+UiStrings.t(" 人"),10,Color.WHITE));JSONArray intents=user.optJSONArray("commonIntents");if(intents!=null&&intents.length()>0){LinearLayout line=new LinearLayout(context);for(int i=0;i<Math.min(2,intents.length());i++){TextView intent=chip(intent(intents.optString(i)),10,palette.accent);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,-2);lp.rightMargin=dp(4);lp.topMargin=dp(3);line.addView(intent,lp);}overlay.addView(line);}        }
        JSONObject presence=user.optJSONObject("presence");if(presence!=null&&"online".equals(presence.optString("state"))){TextView online=chip(UiStrings.t("● 在线"),10,0xff168257);LayoutParams lp=new LayoutParams(-2,-2,Gravity.TOP|Gravity.LEFT);lp.topMargin=dp(7);lp.leftMargin=dp(7);addView(online,lp);}
        if("superlike".equals(action)){TextView superLike=chip(UiStrings.t("★ 超级喜欢"),10,0xffdfa31b);LayoutParams lp=new LayoutParams(-2,-2,Gravity.TOP|Gravity.LEFT);lp.leftMargin=dp(7);lp.topMargin=dp(presence!=null&&"online".equals(presence.optString("state"))?32:7);addView(superLike,lp);}
        addView(overlay,new LayoutParams(-1,-2,Gravity.BOTTOM));danmaku=new DanmakuView(context,api,palette,!large);addView(danmaku,new LayoutParams(-1,-1));danmaku.setClickable(false);setContentDescription(user.optString("displayName")+UiStrings.t("，查看名片"));if(open!=null){setFocusable(true);setOnClickListener(v->open.run());}
    }
    @Override protected void onMeasure(int width,int height){int w=MeasureSpec.getSize(width);super.onMeasure(width,MeasureSpec.makeMeasureSpec((large?Math.min(Math.round(w*(getResources().getConfiguration().screenWidthDp>=640?.625f:1.25f)),Math.round(getResources().getDisplayMetrics().heightPixels*.70f)):Math.round(w*4f/3)),MeasureSpec.EXACTLY));}
    private GradientDrawable topRounded(int color){GradientDrawable d=new GradientDrawable();d.setColor(color);float r=dp(16);d.setCornerRadii(new float[]{r,r,r,r,0,0,0,0});return d;}
    private void largeOverlay(LinearLayout overlay,NativeApi api,ThemePalette palette,JSONObject user){
        LinearLayout identity=new LinearLayout(getContext());identity.setGravity(Gravity.BOTTOM);
        FrameLayout avatar=new FrameLayout(getContext());GradientDrawable ring=background(0xffdedede,40);ring.setStroke(dp(3),0xb3ffffff);avatar.setBackground(ring);avatar.setPadding(dp(3),dp(3),dp(3),dp(3));
        FrameLayout inner=new FrameLayout(getContext());inner.setBackground(background(palette.surface2,36));inner.setClipToOutline(true);AnimatedPhotoView image=new AnimatedPhotoView(getContext());image.palette(palette);inner.addView(image,new LayoutParams(-1,-1));avatar.addView(inner,new LayoutParams(-1,-1));api.image(image,user.optJSONObject("avatar"),true);
        LinearLayout.LayoutParams avatarLp=new LinearLayout.LayoutParams(dp(64),dp(64));avatarLp.rightMargin=dp(12);avatarLp.bottomMargin=dp(2);identity.addView(avatar,avatarLp);
        LinearLayout copy=new LinearLayout(getContext());copy.setOrientation(LinearLayout.VERTICAL);
        TextView name=label(user.optString("displayName"),30,Color.WHITE);name.setTypeface(null,Typeface.BOLD);name.setSingleLine();name.setEllipsize(android.text.TextUtils.TruncateAt.END);copy.addView(name,new LinearLayout.LayoutParams(-1,-2));
        FlowLayout badges=new FlowLayout(getContext());JSONObject shine=user.optJSONObject("shine"),verified=user.optJSONObject("badges");
        if(shine!=null){if(shine.optInt("likes")>0)badges.addView(chip(UiStrings.t("♥ 前 ")+shine.optInt("likes")+"%",10,0xffff63a7));if(shine.optInt("superlikes")>0)badges.addView(chip(UiStrings.t("★ 前 ")+shine.optInt("superlikes")+"%",10,0xffefa52c));}
        if(verified!=null&&verified.optBoolean("vrcVerified")){String trust=ProfileData.trust(verified.optString("vrcTrust"));badges.addView(chip("✓ VRC"+(trust.isEmpty()?UiStrings.t(" 已验证"):" · "+trust),10,0xff8245e7));}
        if(badges.getChildCount()>0){LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(4);lp.bottomMargin=dp(5);copy.addView(badges,lp);}
        TextView tagline=label(ProfileData.text(user,"tagline"),14,0xfff2f2f2);tagline.setMaxLines(3);tagline.setEllipsize(android.text.TextUtils.TruncateAt.END);copy.addView(tagline,new LinearLayout.LayoutParams(-1,-2));identity.addView(copy,new LinearLayout.LayoutParams(0,-2,1));overlay.addView(identity,new LinearLayout.LayoutParams(-1,-2));
        int mutual=user.optInt("mutualMatches"),matches=user.optInt("matchCount");if(mutual>0||matches>0){String summary=(matches>0?UiStrings.t("已配对 ")+matches+UiStrings.t(" 人"):"")+(matches>0&&mutual>0?" · ":"")+(mutual>0?UiStrings.t("共同配对 ")+mutual+UiStrings.t(" 人"):"");info(overlay,"users",summary,10);}
        String time=localTime(user);JSONArray hours=user.optJSONArray("overlapHours");ArrayList<Integer> list=new ArrayList<>();if(hours!=null)for(int i=0;i<hours.length();i++)list.add(hours.optInt(i,-1));String overlap=LikesRules.hours(list);if(!time.isEmpty())info(overlay,"clock",UiStrings.t("当地时间 ")+time+" · "+(overlap.isEmpty()?UiStrings.t("没有重叠的在线时段"):UiStrings.t("共同在线时段 ")+overlap),7);
        JSONObject tonight=user.optJSONObject("tonight");if(tonight!=null&&!tonight.optString("text").isEmpty()){TextView status=chip("☾ "+tonight.optString("text"),11,0xffedb52e);status.setTextColor(0xff27231b);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,-2);lp.topMargin=dp(6);overlay.addView(status,lp);}
    }
    private void info(LinearLayout parent,String icon,String value,int margin){LinearLayout line=new LinearLayout(getContext());line.setGravity(Gravity.CENTER_VERTICAL);line.addView(new SiteIconView(getContext(),icon,0xffededed,false),new LinearLayout.LayoutParams(dp(14),dp(14)));TextView text=label(value,11,0xffededed);LinearLayout.LayoutParams textLp=new LinearLayout.LayoutParams(0,-2,1);textLp.leftMargin=dp(6);line.addView(text,textLp);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(margin);parent.addView(line,lp);}
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private GradientDrawable background(int color,int radius){GradientDrawable d=new GradientDrawable();d.setColor(color);d.setCornerRadius(dp(radius));return d;}
    private TextView label(String value,int size,int color){TextView text=new TextView(getContext());text.setText(value);text.setTextSize(size);text.setTextColor(color);return text;}
    private TextView chip(String value,int size,int color){TextView text=label(value,size,Color.WHITE);text.setGravity(Gravity.CENTER_VERTICAL);text.setPadding(dp(5),dp(1),dp(5),dp(1));text.setBackground(background(color,12));return text;}
    private String intent(String value){Map<String,String> labels=new HashMap<>();labels.put("friends",UiStrings.t("交友"));labels.put("romance",UiStrings.t("恋爱"));labels.put("erp","ERP");labels.put("activity",UiStrings.t("活动"));labels.put("creative",UiStrings.t("创作"));return labels.containsKey(value)?labels.get(value):value;}
    private String localTime(JSONObject user){String zone=user.optString("timezone");java.util.TimeZone timeZone=zone.isEmpty()?new SimpleTimeZone(user.optInt("utcOffsetMin")*60000,"profile"):TimeZone.getTimeZone(zone);if(zone.isEmpty()&&!user.has("utcOffsetMin"))return "";java.text.SimpleDateFormat format=new java.text.SimpleDateFormat("HH:mm",Locale.ROOT);format.setTimeZone(timeZone);return format.format(new Date());}
    void danmaku(JSONArray entries,Runnable open){danmaku.entries(entries,open);}
    DanmakuView danmakuLayer(){return danmaku;}
    void reactionBar(View view){removeView(reactionTop);LayoutParams lp=new LayoutParams(-1,-2,Gravity.TOP);lp.topMargin=dp(8);lp.leftMargin=lp.rightMargin=dp(8);addView(view,lp);}
}
