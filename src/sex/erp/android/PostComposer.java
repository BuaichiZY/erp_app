package sex.erp.android;

import android.app.*;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.*;
import android.text.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.function.*;

/** Native post draft. Uploads only attach media; publishing is a separate explicit action. */
final class PostComposer extends LinearLayout {
    private final Activity activity;
    private final NativeApi api;
    private final JSONObject config,me,initial;
    private ThemePalette palette;
    private final BooleanSupplier current;
    private final Consumer<Consumer<JSONObject>> pickImage;
    private final Consumer<JSONObject> done;
    private final Consumer<NativeApi.Failure> failure;
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final List<JSONObject> media=new ArrayList<>();
    private final Set<String> languages=new LinkedHashSet<>();
    private EditText title,body,worldQuery;
    private TextView titleCount,bodyCount,worldSelected,status;
    private LinearLayout ratings,kinds,worldResults;
    private FlowLayout photos,languageChoices;
    private Button categoryButton,eventButton,durationButton,publish;
    private Switch languageToggle;
    private CheckBox pledge;
    private String category="daily",rating="",kind="",duration="7",worldId="",worldName="";
    private long eventAt=-1;
    private int worldGeneration;
    private Runnable worldSearch;
    private boolean posting,renderedPosting;
    private int mediaRevision,renderedRevision=-1;

    PostComposer(Activity activity,NativeApi api,ThemePalette palette,JSONObject config,JSONObject me,JSONObject initial,BooleanSupplier current,Consumer<Consumer<JSONObject>> pickImage,Consumer<JSONObject> done,Consumer<NativeApi.Failure> failure){
        super(activity);this.activity=activity;this.api=api;this.palette=palette;this.config=config;this.me=me;this.initial=initial;this.current=current;this.pickImage=pickImage;this.done=done;this.failure=failure;setOrientation(VERTICAL);
        if(initial!=null){category=initial.optString("category","daily");rating=initial.optString("rating");kind=initial.optString("r18Kind");duration="keep";eventAt=EnergyTime.timestamp(initial.optString("eventAt"));JSONObject world=initial.optJSONObject("world");if(world!=null){worldId=world.optString("id");worldName=world.optString("name");}JSONArray items=initial.optJSONArray("media");if(items!=null)for(int i=0;i<items.length();i++)if(items.optJSONObject(i)!=null)media.add(items.optJSONObject(i));JSONArray langs=initial.optJSONArray("languages");if(langs!=null)for(int i=0;i<langs.length();i++)languages.add(langs.optString(i));}
        section(UiStrings.t("分类"));categoryButton=button(PostRules.category(category),()->{String[] labels=UiStrings.list(Arrays.copyOf(PostRules.LABELS,8));new SiteDialog.Builder(activity,palette).setTitle(UiStrings.t("分类")).setItems(labels,(d,w)->{category=PostRules.CATEGORIES[w];categoryButton.setText(labels[w]);update();}).show();});add(categoryButton);
        section(UiStrings.t("标题 *"));title=edit(UiStrings.t("给贴文起个标题"),initial==null?"":original(initial,"title"),false);titleCount=label("",11,palette.muted);add(titleCount);
        section(UiStrings.t("内容"));body=edit(UiStrings.t("分享日常、安排或想法…"),initial==null?"":original(initial,"body"),true);body.setMinLines(6);bodyCount=label("",11,palette.muted);add(bodyCount);
        section(UiStrings.t("内容分级 *"));ratings=row();add(ratings);kinds=row();add(kinds);
        section(UiStrings.t("活动时间（可选）"));LinearLayout dates=row();eventButton=button(UiStrings.t("选择日期和时间"),this::chooseDate);dates.addView(eventButton,new LayoutParams(0,dp(40),1));Button clear=button(UiStrings.t("清除"),()->{eventAt=-1;update();});LayoutParams clearLp=new LayoutParams(dp(60),dp(40));clearLp.leftMargin=dp(8);dates.addView(clear,clearLp);add(dates);
        section(UiStrings.t("展示期限"));durationButton=button(UiStrings.t("7 天"),()->{String[] values={"1","3","7","14","30","long"},labels={UiStrings.t("1 天"),UiStrings.t("3 天"),UiStrings.t("7 天"),UiStrings.t("14 天"),UiStrings.t("30 天"),UiStrings.t("长期展示")};new SiteDialog.Builder(activity,palette).setTitle(UiStrings.t("展示期限")).setItems(labels,(d,w)->{duration=values[w];update();}).show();});add(durationButton);
        section(UiStrings.t("世界（可选）"));worldSelected=label("",13,palette.text);worldSelected.setPadding(dp(8),dp(6),dp(8),dp(6));worldSelected.setOnClickListener(v->{if(posting)return;worldId="";worldName="";update();});add(worldSelected);worldQuery=edit(UiStrings.t("搜索世界名称或粘贴 VRChat 世界链接"),"",false);worldQuery.setSingleLine();worldResults=column();add(worldResults);
        worldQuery.addTextChangedListener(watcher(()->{if(worldSearch!=null)ui.removeCallbacks(worldSearch);final int generation=++worldGeneration;worldSearch=()->searchWorld(generation);ui.postDelayed(worldSearch,500);}));
        languageToggle=new Switch(activity);languageToggle.setText(UiStrings.t("设置语言偏好"));languageToggle.setTextColor(palette.text);languageToggle.setChecked(!languages.isEmpty());add(languageToggle);languageChoices=new FlowLayout(activity);add(languageChoices);languageToggle.setOnCheckedChangeListener((v,on)->update());
        section(UiStrings.t("照片"));photos=new FlowLayout(activity);add(photos);
        pledge=new CheckBox(activity);pledge.setText(UiStrings.t("我已阅读并同意遵守社区发布规则"));pledge.setTextColor(palette.text);add(pledge);pledge.setOnCheckedChangeListener((v,on)->update());
        status=label("",12,palette.muted);add(status);publish=button(initial==null?UiStrings.t("发布"):UiStrings.t("保存修改"),this::submit);add(publish);
        title.addTextChangedListener(watcher(this::update));body.addTextChangedListener(watcher(this::update));setFocusableInTouchMode(true);requestFocus();update();
    }
    private String original(JSONObject post,String key){JSONObject tr=post.optJSONObject("i18n");String original=tr==null?"":tr.optString("original"+Character.toUpperCase(key.charAt(0))+key.substring(1));return original.isEmpty()?ProfileData.text(post.opt(key)):original;}
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    private LinearLayout column(){LinearLayout row=new LinearLayout(activity);row.setOrientation(VERTICAL);return row;}
    private LinearLayout row(){LinearLayout row=new LinearLayout(activity);row.setGravity(Gravity.CENTER_VERTICAL);return row;}
    private GradientDrawable background(int color,int radius){if(palette.pop)return new PopDrawable(color,dp(radius),palette.border,getResources().getDisplayMetrics().density);GradientDrawable bg=new GradientDrawable();bg.setColor(color);bg.setCornerRadius(dp(radius));bg.setStroke(dp(1),palette.border);return bg;}
    private TextView label(String text,int size,int color){TextView v=new TextView(activity);v.setText(text);v.setTextSize(size);v.setTextColor(color);return v;}
    private void section(String name){TextView heading=label(name,14,palette.text);heading.setTypeface(null,android.graphics.Typeface.BOLD);LayoutParams lp=new LayoutParams(-1,-2);lp.topMargin=dp(8);lp.bottomMargin=dp(8);addView(heading,lp);}
    private void add(View v){LayoutParams lp=new LayoutParams(-1,-2);lp.bottomMargin=dp(12);addView(v,lp);}
    private Button button(String text,Runnable click){Button b=new Button(activity);b.setText(text);b.setAllCaps(false);b.setTextSize(13);b.setTextColor(palette.text);b.setMinHeight(0);b.setMinimumHeight(0);b.setPadding(dp(10),dp(9),dp(10),dp(9));b.setBackground(background(palette.surface,12));b.setStateListAnimator(null);b.setOnClickListener(v->click.run());return b;}
    private EditText edit(String hint,String value,boolean multiline){EditText e=new EditText(activity);e.setTextColor(palette.text);e.setHintTextColor(palette.muted);e.setTextSize(14);e.setInputType(InputType.TYPE_CLASS_TEXT|(multiline?InputType.TYPE_TEXT_FLAG_MULTI_LINE:0));if(!multiline)e.setSingleLine();e.setGravity(Gravity.TOP);e.setPadding(dp(12),dp(10),dp(12),dp(10));e.setBackground(background(palette.surface,12));e.setHint(hint);e.setText(value);add(e);return e;}
    private TextWatcher watcher(Runnable changed){return new TextWatcher(){public void beforeTextChanged(CharSequence s,int a,int c,int f){}public void onTextChanged(CharSequence s,int a,int b,int c){}public void afterTextChanged(Editable e){changed.run();}};}
    private boolean restricted(String feature){if("restricted".equals(me.optString("status")))return true;JSONArray limits=me.optJSONArray("featureLimits");if(limits!=null)for(int i=0;i<limits.length();i++)if(feature.equals(limits.optString(i)))return true;return false;}
    private int limit(String name,int fallback){JSONObject limits=config.optJSONObject("limits");return limits==null?fallback:limits.optInt(name,fallback);}
    private String validation(){return PostRules.validate(title.getText().toString(),body.getText().toString(),category,rating,kind,restricted("upload_nsfw"),pledge.isChecked(),limit("postTitleMax",80),limit("postBodyMax",2000));}
    private void update(){
        if(publish==null)return;String a=title.getText().toString(),b=body.getText().toString();int titleLength=a.codePointCount(0,a.length()),bodyLength=b.codePointCount(0,b.length());titleCount.setText(titleLength+" / "+limit("postTitleMax",80));bodyCount.setText(bodyLength+" / "+limit("postBodyMax",2000));titleCount.setTextColor(titleLength>limit("postTitleMax",80)?palette.accent:palette.muted);bodyCount.setTextColor(bodyLength>limit("postBodyMax",2000)?palette.accent:palette.muted);
        if(restricted("upload_nsfw")&&!rating.equals("general")||!restricted("upload_nsfw")&&category.equals("erp")&&rating.equals("general"))rating="";
        ratings.removeAllViews();String[] codes={"general","suggestive","r18"},labels={UiStrings.t("全年龄"),UiStrings.t("擦边"),"R18"};for(int i=0;i<3;i++){String code=codes[i];Button choice=button(labels[i],()->{rating=code;update();});choice.setTextColor(rating.equals(code)?palette.accent:palette.text);choice.setBackground(background(rating.equals(code)?palette.soft:palette.surface,12));boolean allowed=restricted("upload_nsfw")?i==0:!category.equals("erp")||i>0;choice.setEnabled(allowed&&!posting);choice.setAlpha(allowed?1:.4f);LayoutParams lp=new LayoutParams(0,dp(40),1);lp.rightMargin=i==2?0:dp(8);ratings.addView(choice,lp);}
        kinds.removeAllViews();kinds.setVisibility(rating.equals("r18")?VISIBLE:GONE);String[] kindCodes={"sexual","gore"},kindLabels={UiStrings.t("成人内容"),UiStrings.t("血腥内容")};for(int i=0;i<2;i++){String code=kindCodes[i];Button choice=button(kindLabels[i],()->{kind=code;update();});choice.setTextColor(kind.equals(code)?palette.accent:palette.text);choice.setEnabled(!posting);LayoutParams lp=new LayoutParams(0,dp(40),1);lp.rightMargin=i==1?0:dp(8);kinds.addView(choice,lp);}
        eventButton.setText(eventAt<0?UiStrings.t("选择日期和时间"):new SimpleDateFormat("yyyy-MM-dd HH:mm",UiStrings.locale()).format(new Date(eventAt)));durationButton.setText(duration.equals("keep")?UiStrings.t("保持当前期限"):duration.equals("long")?UiStrings.t("长期展示"):duration+UiStrings.t(" 天"));worldSelected.setVisibility(worldId.isEmpty()?GONE:VISIBLE);worldSelected.setText(worldName+"  ×");worldSelected.setBackground(background(palette.surface2,10));
        languageChoices.removeAllViews();languageChoices.setVisibility(languageToggle.isChecked()?VISIBLE:GONE);for(int i=0;i<DiscoverFilters.VALUES[2].length;i++){String code=DiscoverFilters.VALUES[2][i];Button chip=button(UiStrings.t(DiscoverFilters.LABELS[2][i]),()->{if(!languages.add(code))languages.remove(code);update();});chip.setTextColor(languages.contains(code)?palette.accent:palette.text);chip.setBackground(background(languages.contains(code)?palette.soft:palette.surface,18));chip.setEnabled(!posting);languageChoices.addView(chip,new ViewGroup.LayoutParams(-2,dp(36)));}
        if(renderedRevision!=mediaRevision||renderedPosting!=posting){renderPhotos();renderedRevision=mediaRevision;renderedPosting=posting;}publish.setText(posting?UiStrings.t("正在提交…"):initial==null?UiStrings.t("发布"):UiStrings.t("保存修改"));publish.setBackground(background(palette.accent,14));publish.setTextColor(Color.WHITE);publish.setEnabled(!posting&&!restricted("post")&&validation().isEmpty());publish.setAlpha(publish.isEnabled()?1:.5f);worldSelected.setEnabled(!posting);status.setText(restricted("post")?UiStrings.t("当前账号暂时无法发布贴文"):posting?UiStrings.t("正在保存，请稍候"):"");
    }
    private void renderPhotos(){photos.removeAllViews();for(JSONObject photo:media){FrameLayout frame=new FrameLayout(activity);AnimatedPhotoView image=new AnimatedPhotoView(activity);image.palette(palette);image.setScaleType(ImageView.ScaleType.CENTER_CROP);frame.addView(image,new FrameLayout.LayoutParams(-1,-1));api.image(image,photo,true);Button remove=button("×",()->{media.remove(photo);mediaRevision++;update();});remove.setPadding(0,0,0,0);remove.setTextColor(Color.WHITE);remove.setBackground(background(0xaa000000,16));remove.setEnabled(!posting);frame.addView(remove,new FrameLayout.LayoutParams(dp(26),dp(26),Gravity.TOP|Gravity.RIGHT));photos.addView(frame,new ViewGroup.LayoutParams(dp(90),dp(90)));}if(media.size()<limit("postPhotosMax",9)){Button add=button(UiStrings.t("＋ 添加照片"),()->{if(posting)return;pickImage.accept(upload->{if(!current.getAsBoolean()||posting)return;JSONObject photo=upload.optJSONObject("media");if(photo==null)photo=upload;if(photo.optString("id").isEmpty()){Toast.makeText(activity,UiStrings.t("上传未返回可用照片"),Toast.LENGTH_LONG).show();return;}if(media.size()<limit("postPhotosMax",9)){media.add(photo);mediaRevision++;}update();});});add.setEnabled(!posting);photos.addView(add,new ViewGroup.LayoutParams(dp(108),dp(90)));}}
    private void chooseDate(){
        Calendar calendar=Calendar.getInstance();if(eventAt>=0)calendar.setTimeInMillis(eventAt);
        DatePicker date=new DatePicker(AppLanguage.context(activity));date.init(calendar.get(Calendar.YEAR),calendar.get(Calendar.MONTH),calendar.get(Calendar.DAY_OF_MONTH),null);
        new SiteDialog.Builder(activity,palette).setTitle(UiStrings.t("选择日期和时间")).setView(date)
            .setPositiveButton(UiStrings.t("下一步"),(dialog,which)->{
                calendar.set(date.getYear(),date.getMonth(),date.getDayOfMonth());
                TimePicker time=new TimePicker(AppLanguage.context(activity));time.setIs24HourView(true);
                time.setHour(calendar.get(Calendar.HOUR_OF_DAY));time.setMinute(calendar.get(Calendar.MINUTE));
                new SiteDialog.Builder(activity,palette).setTitle(UiStrings.t("选择日期和时间")).setView(time)
                    .setPositiveButton(UiStrings.t("应用"),(second,selected)->{
                        calendar.set(Calendar.HOUR_OF_DAY,time.getHour());calendar.set(Calendar.MINUTE,time.getMinute());
                        calendar.set(Calendar.SECOND,0);calendar.set(Calendar.MILLISECOND,0);
                        eventAt=calendar.getTimeInMillis();update();
                    }).setNegativeButton(UiStrings.t("取消"),null).show();
            }).setNegativeButton(UiStrings.t("取消"),null).show();
    }
    private void searchWorld(int generation){if(!current.getAsBoolean()||generation!=worldGeneration)return;if(android.view.inputmethod.BaseInputConnection.getComposingSpanStart(worldQuery.getText())>=0){ui.postDelayed(worldSearch,500);return;}String query=worldQuery.getText().toString().trim();worldResults.removeAllViews();if(query.codePointCount(0,query.length())<2)return;worldResults.addView(label(UiStrings.t("正在搜索…"),12,palette.muted));api.call("GET","/worlds/search?q="+NativeApi.encode(query),null,(result,error)->{if(!current.getAsBoolean()||generation!=worldGeneration||!isAttachedToWindow())return;worldResults.removeAllViews();if(error!=null){Button retry=button(UiStrings.t("搜索失败，点击重试"),()->searchWorld(generation));worldResults.addView(retry);return;}JSONArray list=result instanceof JSONArray?(JSONArray)result:NativeApi.object(result).optJSONArray("items");if(list==null||list.length()==0){worldResults.addView(label(UiStrings.t("没有找到世界"),12,palette.muted));return;}for(int i=0;i<list.length();i++){JSONObject world=list.optJSONObject(i);if(world==null)continue;Button select=button(world.optString("name"),()->{if(posting)return;worldId=world.optString("id");worldName=world.optString("name");worldGeneration++;worldQuery.setText("");worldResults.removeAllViews();update();});LayoutParams lp=new LayoutParams(-1,dp(40));lp.bottomMargin=dp(6);worldResults.addView(select,lp);}});}
    private String iso(long millis){SimpleDateFormat date=new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",Locale.US);date.setTimeZone(TimeZone.getTimeZone("UTC"));return date.format(new Date(millis));}
    private void submit(){if(posting||!current.getAsBoolean())return;String invalid=validation();if(!invalid.isEmpty()){Toast.makeText(activity,invalid,Toast.LENGTH_LONG).show();return;}JSONObject payload=NativeApi.json("category",category,"title",title.getText().toString().trim(),"body",body.getText().toString().trim(),"rating",rating);JSONArray ids=new JSONArray();for(JSONObject photo:media)ids.put(photo.optString("id"));try{payload.put("mediaIds",ids);payload.put("languages",new JSONArray(languageToggle.isChecked()?languages:Collections.emptySet()));if(rating.equals("r18"))payload.put("r18Kind",kind);payload.put("worldId",worldId.isEmpty()?JSONObject.NULL:worldId);payload.put("eventAt",eventAt<0?JSONObject.NULL:iso(eventAt));if(!duration.equals("keep"))payload.put("expiresAt",duration.equals("long")?JSONObject.NULL:iso(System.currentTimeMillis()+Long.parseLong(duration)*86400000L));}catch(JSONException ignored){}
        posting=true;disableFields(this,false);update();api.call(initial==null?"POST":"PATCH",initial==null?"/posts":"/posts/"+NativeApi.encode(initial.optString("id")),payload,(result,error)->{if(!current.getAsBoolean()||!isAttachedToWindow())return;posting=false;disableFields(this,true);update();if(error!=null)failure.accept(error);else done.accept(NativeApi.object(result));});
    }
    private void disableFields(View view,boolean enabled){if(view instanceof EditText||view instanceof Button||view instanceof CompoundButton)view.setEnabled(enabled);if(view instanceof ViewGroup){ViewGroup group=(ViewGroup)view;for(int i=0;i<group.getChildCount();i++)disableFields(group.getChildAt(i),enabled);}}
    void palette(ThemePalette value){palette=value;renderedRevision=-1;update();}
    @Override protected void onDetachedFromWindow(){worldGeneration++;ui.removeCallbacksAndMessages(null);super.onDetachedFromWindow();}
}
