package sex.erp.android;

import android.app.Activity;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.RadioButton;
import android.widget.RadioGroup;
import android.widget.Switch;
import android.widget.TextView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

/** Native counterpart to the site's match icebreaker sheet. Suggestions only fill the composer. */
final class IcebreakerDialog {
    private final Activity activity;
    private final ThemePalette palette;
    private final NativeApi api;
    private final String matchId,peerName;
    private final BooleanSupplier canAct;
    private final Consumer<String> onPick,onError;
    private final LinearLayout body;
    private SiteDialog sheet;
    private JSONObject ice;
    private String tab="common";
    private boolean busy;
    private String failure;

    IcebreakerDialog(Activity activity,ThemePalette palette,NativeApi api,String matchId,String peerName,BooleanSupplier canAct,Consumer<String> onPick,Consumer<String> onError){
        this.activity=activity;this.palette=palette;this.api=api;this.matchId=matchId;this.peerName=peerName;this.canAct=canAct;this.onPick=onPick;this.onError=onError;
        body=column();
    }
    void show(){render();sheet=new SiteDialog.Builder(activity,palette).setTitle(UiStrings.t("✧ 破冰")).setView(body).show();load();}
    private void load(){failure=null;api.call("GET",path(),null,(result,error)->{if(!visible())return;if(error!=null){failure=error.getMessage();render();return;}ice=object(result);render();});}
    private String path(){return "/matches/"+NativeApi.encode(matchId)+"/icebreaker";}
    private boolean visible(){return sheet!=null&&sheet.isShowing()&&!activity.isFinishing();}
    private void act(String method,String suffix,JSONObject payload){if(busy)return;busy=true;api.call(method,path()+suffix,payload,(result,error)->{busy=false;if(!visible())return;if(error!=null){onError.accept(error.getMessage());render();return;}JSONObject update=object(result);if(update.has("quiz")||update.has("common")||update.has("adult")){ice=update;render();}else load();});}
    private void render(){body.removeAllViews();LinearLayout tabs=new LinearLayout(activity);tabs.setOrientation(LinearLayout.HORIZONTAL);String[] keys={"common","dealbreakers","quiz","adult"};String[] labels={"共同点","TA 的雷点","双盲问答","成人区"};for(int i=0;i<keys.length;i++){if(i==3&&(ice==null||!object(ice.opt("adult")).optBoolean("available")))continue;String next=keys[i];TextView label=label(UiStrings.t(labels[i]),13,next.equals(tab)?palette.text:palette.muted);label.setGravity(Gravity.CENTER);label.setTypeface(null,next.equals(tab)?Typeface.BOLD:Typeface.NORMAL);label.setPadding(dp(3),dp(12),dp(3),dp(12));tabs.addView(label,new LinearLayout.LayoutParams(0,dp(45),1));label.setOnClickListener(v->{tab=next;render();});}body.addView(tabs);View line=new View(activity);line.setBackgroundColor(palette.border);body.addView(line,new LinearLayout.LayoutParams(-1,dp(1)));
        if(ice==null){paragraph(failure==null?UiStrings.t("正在加载…"):failure);if(failure!=null)action(UiStrings.t("重试"),false,this::load);finish();return;}
        switch(tab){case "dealbreakers":dealbreakers();break;case "quiz":quiz();break;case "adult":adult();break;default:common();break;}
        finish();
    }
    private void finish(){if(sheet!=null)body.post(()->{if(visible())sheet.relayout();});}
    private void common(){JSONObject common=object(ice.opt("common"));JSONArray same=array(common,"sameAnswers"),peer=array(common,"peerAnswers");
        if(empty(common,"intents","tags","likes","worlds","baseAvatars","baseAvatarCustom","models","languages","sameAnswers","peerAnswers","overlapHours")){paragraph(UiStrings.t("还没有找到共同点，试试双盲问答吧。"));return;}
        paragraph(UiStrings.t("点一下，开场白会放进输入框。"));
        questionList(UiStrings.t("问卷选了一样的"),same,true);
        namedSection(UiStrings.t("共同来意"),array(common,"intents"),"intent",true);
        JSONArray avatars=new JSONArray();copy(avatars,array(common,"baseAvatars"));copy(avatars,array(common,"baseAvatarCustom"));namedSection(UiStrings.t("相同素体"),avatars,"avatar",true);
        namedSection(UiStrings.t("同款模型"),array(common,"models"),"model",true);
        namedSection(UiStrings.t("都喜欢的世界"),array(common,"worlds"),"world",true);
        namedSection(UiStrings.t("都喜欢"),array(common,"likes"),"like",true);
        namedSection(UiStrings.t("共同标签"),array(common,"tags"),"tag",true);
        Object hours=common.opt("overlapHours");if(hours!=null&&hours!=JSONObject.NULL){String display=hours instanceof JSONArray?formatHours((JSONArray)hours):String.valueOf(hours);if(!display.isEmpty()&&!"[]".equals(display)){section(UiStrings.t("都常在线（你的时间）"));body.addView(chip(display,()->pick("hours","",display,""),false));}}
        namedSection(UiStrings.t("都会的语言"),array(common,"languages"),"",false);
        questionList(UiStrings.t("TA 的问卷"),peer,false);
    }
    private void dealbreakers(){JSONObject deal=object(ice.opt("dealbreakers"));if(empty(deal,"hits","tags","dislikes","limitsNo")&&value(deal,"note").isEmpty()&&value(deal,"safeword").isEmpty()){paragraph(UiStrings.t("TA 没有写雷点。"));return;}
        namedSection(UiStrings.t("你的名片有 TA 的雷点"),array(deal,"hits"),"",false);
        namedSection(UiStrings.t("雷点"),array(deal,"tags"),"",false);
        if(!value(deal,"note").isEmpty()){section(UiStrings.t("备注"));paragraph(value(deal,"note"));}
        namedSection(UiStrings.t("不喜欢"),array(deal,"dislikes"),"",false);
        namedSection(UiStrings.t("底线（不行）"),array(deal,"limitsNo"),"",false);
        if(!value(deal,"safeword").isEmpty()){section(UiStrings.t("安全词"));paragraph(value(deal,"safeword"));}
    }
    private void adult(){JSONObject adult=object(ice.opt("adult"));if(!adult.optBoolean("available")){tab="common";render();return;}Switch enabled=new Switch(activity);enabled.setText(UiStrings.t("成人区"));enabled.setTextColor(palette.text);enabled.setTextSize(14);enabled.setChecked(adult.optBoolean("on"));enabled.setEnabled(!busy);space(enabled);enabled.setOnCheckedChangeListener((button,checked)->act("PUT","/adult",NativeApi.json("on",checked)));paragraph(UiStrings.t("开启后会显示双方共同的 R18 喜好，双盲问答也会加入成人题目。"));if(adult.optBoolean("on")){JSONArray likes=array(adult,"likes");if(likes.length()==0)paragraph(UiStrings.t("目前没有共同的 R18 喜好。"));else namedSection(UiStrings.t("共同的 R18 喜好"),likes,"adult",true);}}
    private void quiz(){JSONObject quiz=object(ice.opt("quiz")),open=object(quiz.opt("open")),last=object(quiz.opt("last"));String openId=value(open,"id");
        if(!openId.isEmpty()){
            if(open.optBoolean("myDone")){paragraph(UiStrings.t("你交卷了，等待对方作答。"));if(open.optBoolean("startedByMe"))action(UiStrings.t("取消这一轮"),false,()->act("DELETE","/rounds/"+NativeApi.encode(openId),null));}
            else if(canAct.getAsBoolean())answerRound(open);
            else paragraph(UiStrings.t("现在无法作答。"));
        }else{paragraph(UiStrings.t("双方都交卷后，答案会同时揭晓。"));action(last.has("id")?UiStrings.t("再来一轮"):UiStrings.t("开始一轮"),true,()->act("POST","/rounds",new JSONObject()));}
        if(last.has("id")){if(!last.optBoolean("seen")){try{last.put("seen",true);}catch(JSONException ignored){}api.call("POST",path()+"/rounds/"+NativeApi.encode(value(last,"id"))+"/seen",new JSONObject(),(r,e)->{});}showResult(last);}
    }
    private void answerRound(JSONObject round){JSONArray questions=array(round,"questions");if(!round.optBoolean("startedByMe"))paragraph(peerName+UiStrings.t(" 邀请你一起答题"));Map<String,LinkedHashSet<String>> answers=new LinkedHashMap<>();
        for(int i=0;i<questions.length();i++){JSONObject question=questions.optJSONObject(i);if(question==null)continue;String id=value(question,"id");LinkedHashSet<String> picked=new LinkedHashSet<>();answers.put(id,picked);section((i+1)+". "+value(question,"text")+("r18".equals(value(question,"rating"))?" · R18":""));JSONArray options=array(question,"options");if("single".equals(value(question,"type"))){RadioGroup group=new RadioGroup(activity);for(int n=0;n<options.length();n++){JSONObject option=options.optJSONObject(n);if(option==null)continue;RadioButton choice=new RadioButton(activity);choice.setText(value(option,"text"));choice.setTextColor(palette.text);choice.setTextSize(14);String optionId=value(option,"id");choice.setOnClickListener(v->{picked.clear();picked.add(optionId);});group.addView(choice);}space(group);}else for(int n=0;n<options.length();n++){JSONObject option=options.optJSONObject(n);if(option==null)continue;CheckBox choice=new CheckBox(activity);choice.setText(value(option,"text"));choice.setTextColor(palette.text);choice.setTextSize(14);String optionId=value(option,"id");choice.setOnCheckedChangeListener((button,checked)->{if(checked)picked.add(optionId);else picked.remove(optionId);});space(choice);}}
        JSONObject wish=object(round.opt("wish"));LinkedHashSet<String> wishes=new LinkedHashSet<>();JSONArray candidates=array(wish,"candidates");int max=wish.optInt("max",0);if(candidates.length()>0){section(UiStrings.t("想和对方一起试的"));paragraph(UiStrings.t("只有双方都选中的项目才会揭晓。"));for(int i=0;i<candidates.length();i++){JSONObject option=candidates.optJSONObject(i);if(option==null)continue;CheckBox check=new CheckBox(activity);check.setText(value(option,"name"));check.setTextColor(palette.text);check.setTextSize(14);String key=value(option,"key");check.setOnCheckedChangeListener((button,checked)->{if(checked&&max>0&&wishes.size()>=max){check.setChecked(false);return;}if(checked)wishes.add(key);else wishes.remove(key);});space(check);}}
        paragraph(UiStrings.t("交卷后不能修改。"));action(UiStrings.t("交卷"),true,()->{JSONObject payload=new JSONObject(),selected=new JSONObject();for(Map.Entry<String,LinkedHashSet<String>> entry:answers.entrySet()){if(entry.getValue().isEmpty()){onError.accept(UiStrings.t("请回答全部问题"));return;}try{selected.put(entry.getKey(),new JSONArray(entry.getValue()));}catch(JSONException ignored){}}try{payload.put("answers",selected);if(candidates.length()>0)payload.put("wishes",new JSONArray(wishes));}catch(JSONException ignored){}act("PUT","/rounds/"+NativeApi.encode(value(round,"id"))+"/answers",payload);});
    }
    private void showResult(JSONObject result){section(UiStrings.t("揭晓结果"));JSONArray questions=array(result,"questions");JSONObject mine=object(result.opt("mine")),peer=object(result.opt("peer"));for(int i=0;i<questions.length();i++){JSONObject question=questions.optJSONObject(i);if(question==null)continue;paragraph(value(question,"text"));String id=value(question,"id");paragraph(UiStrings.t("我")+"："+answersText(question,array(mine,id)));paragraph(peerName+"："+answersText(question,array(peer,id)));}JSONArray mutual=array(object(result.opt("wish")),"mutual");if(mutual.length()>0)namedSection(UiStrings.t("你们都想试的"),mutual,"",false);}
    private String answersText(JSONObject question,JSONArray ids){ArrayList<String> found=new ArrayList<>();JSONArray options=array(question,"options");for(int i=0;i<ids.length();i++)for(int j=0;j<options.length();j++){JSONObject option=options.optJSONObject(j);if(option!=null&&ids.optString(i).equals(value(option,"id")))found.add(value(option,"text"));}return android.text.TextUtils.join("、",found);}
    private void questionList(String heading,JSONArray questions,boolean same){if(questions.length()==0)return;section(heading);for(int i=0;i<questions.length();i++){JSONObject answer=questions.optJSONObject(i);if(answer==null)continue;String question=value(answer,"question"),value=value(answer,"answer");LinearLayout card=column();card.setPadding(dp(12),dp(9),dp(12),dp(9));card.setBackground(outline(palette.surface,palette.border,12));card.addView(label(question,12,palette.muted));TextView answerText=label(value,14,palette.text);answerText.setTypeface(null,Typeface.BOLD);card.addView(answerText);space(card);card.setOnClickListener(v->pick(same?"same":"peer",question,value,""));}}
    private void namedSection(String heading,JSONArray values,String opener,boolean clickable){if(values.length()==0)return;section(heading);LinearLayout wrap=column();space(wrap);LinearLayout row=null;int count=0;for(int i=0;i<values.length();i++){Object item=values.opt(i);String name=item instanceof JSONObject?value((JSONObject)item,"name"):item==null?"":String.valueOf(item);if("intent".equals(opener))name=intent(name);if("".equals(opener)&&heading.equals(UiStrings.t("都会的语言")))name=language(name);if(name.isEmpty())continue;if(row==null||count>=3){row=new LinearLayout(activity);row.setOrientation(LinearLayout.HORIZONTAL);wrap.addView(row);count=0;}String selected=name;TextView chip=chip(name,clickable?()->pick(opener,"",selected,""):null,false);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-2,-2);lp.rightMargin=dp(5);lp.bottomMargin=dp(5);row.addView(chip,lp);count++;}}
    private String intent(String value){switch(value){case "friends":return UiStrings.t("交朋友");case "romance":return UiStrings.t("恋爱");case "erp":return UiStrings.t("成人互动");case "activity":return UiStrings.t("一起玩");case "creative":return UiStrings.t("创作");case "browsing":return UiStrings.t("随便看看");case "other":return UiStrings.t("其他");default:return value;}}
    private String language(String value){switch(value){case "zh":return UiStrings.t("中文");case "ja":return UiStrings.t("日文");case "en":return UiStrings.t("英文");case "ko":return UiStrings.t("韩文");default:return value;}}
    private static String formatHours(JSONArray values){int[] hours=new int[values.length()];for(int i=0;i<values.length();i++)hours[i]=values.optInt(i,-1);return IcebreakerHours.format(hours);}
    private void pick(String kind,String question,String name,String ignored){String template;switch(kind){case "same":template=UiStrings.t("「{{question}}」我们都选了「{{answer}}」！");break;case "peer":template=UiStrings.t("看到你在「{{question}}」回答「{{answer}}」，可以多说一点吗？");break;case "intent":template=UiStrings.t("我们的来意都有「{{name}}」，你最想遇到什么样的人？");break;case "tag":template=UiStrings.t("看到你也有「{{name}}」，想多听你聊聊！");break;case "like":template=UiStrings.t("你也喜欢{{name}}吗？");break;case "world":template=UiStrings.t("你也喜欢「{{name}}」吗？要不要一起去？");break;case "avatar":template=UiStrings.t("你也在用{{name}}吗？");break;case "model":template=UiStrings.t("我们用的是同款模型「{{name}}」耶！");break;case "hours":template=UiStrings.t("我们都常在 {{hours}} 上线，要不要约那时候见？");break;case "adult":template=UiStrings.t("看到我们都对{{name}}有兴趣，想听听你的想法～");break;default:return;}String opener=template.replace("{{name}}",name).replace("{{hours}}",name).replace("{{question}}",question).replace("{{answer}}",name);onPick.accept(opener);if(sheet!=null)sheet.dismiss();}
    private void section(String title){TextView heading=label(title,12,palette.muted);heading.setTypeface(null,Typeface.BOLD);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(15);body.addView(heading,lp);}
    private void paragraph(String text){TextView copy=label(text,13,palette.muted);space(copy);}
    private void action(String text,boolean primary,Runnable click){Button button=new Button(activity);button.setAllCaps(false);button.setText(text);button.setTextSize(14);button.setTextColor(primary?android.graphics.Color.WHITE:palette.text);button.setBackground(outline(primary?palette.accent:palette.surface2,primary?palette.accent:palette.border,20));button.setEnabled(!busy&&(!primary||canAct.getAsBoolean()));LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,dp(44));lp.topMargin=dp(12);body.addView(button,lp);button.setOnClickListener(v->click.run());}
    private TextView chip(String text,Runnable click,boolean danger){TextView item=label(text,13,danger?palette.accent:palette.text);item.setPadding(dp(10),dp(5),dp(10),dp(5));item.setBackground(outline(palette.surface2,palette.border,18));if(click!=null){item.setFocusable(true);item.setOnClickListener(v->click.run());}return item;}
    private void space(View view){LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.topMargin=dp(8);body.addView(view,lp);}
    private LinearLayout column(){LinearLayout result=new LinearLayout(activity);result.setOrientation(LinearLayout.VERTICAL);return result;}
    private TextView label(String text,int size,int color){TextView label=new TextView(activity);label.setText(text);label.setTextColor(color);label.setTextSize(size);return label;}
    private GradientDrawable outline(int fill,int stroke,int radius){GradientDrawable result=new GradientDrawable();result.setColor(fill);result.setStroke(dp(1),stroke);result.setCornerRadius(dp(radius));return result;}
    private int dp(int n){return Math.round(n*activity.getResources().getDisplayMetrics().density);}
    private static JSONObject object(Object o){return o instanceof JSONObject?(JSONObject)o:new JSONObject();}
    private static JSONArray array(JSONObject object,String key){JSONArray result=object.optJSONArray(key);return result==null?new JSONArray():result;}
    private static String value(JSONObject object,String key){return object.optString(key,"");}
    private static boolean empty(JSONObject object,String... keys){for(String key:keys){Object found=object.opt(key);if(found instanceof JSONArray&&((JSONArray)found).length()>0)return false;if(found!=null&&found!=JSONObject.NULL&&!(found instanceof JSONArray)&&!String.valueOf(found).isEmpty())return false;}return true;}
    private static void copy(JSONArray target,JSONArray values){for(int i=0;i<values.length();i++)target.put(values.opt(i));}
}
