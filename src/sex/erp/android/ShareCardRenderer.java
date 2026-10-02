package sex.erp.android;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Shader;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.LinkedHashSet;
import java.util.Locale;
import io.nayuki.qrcodegen.QrCode;

/** Draws the same share-card content locally for preview and PNG export. */
final class ShareCardRenderer {
    static final String[] FORMATS={"og","1x1","4x5","9x16"};
    static final String[] STYLES={"poster","card","type","night","minimal"};
    static final String[] PALETTES={"red","ink","sea","mint","milk"};
    static final String[] FIELDS={"tagline","intents","tags","platform","speech","langs","time","avatar","shine","vrc","qr"};
    static final String[] FIELD_LABELS={"一句话简介","来意","标签","平台","说话方式","语言","当地时间","素体","闪亮标签","VRChat 名称","二维码"};
    static final int[] COLORS={0xffff5a4e,0xff17181c,0xff2f6bf0,0xff0e9f76,0xff8b5e3c};
    static final class Config {
        String style="card",palette="red",photoId="",text="";
        boolean brand=true,invite=true;
        LinkedHashSet<String> fields=new LinkedHashSet<>();
        static Config read(String format,JSONObject value){Config c=new Config();c.style="og".equals(format)?"card":"poster";for(String field:new String[]{"tagline","intents","tags","platform","speech","langs","shine","qr"})c.fields.add(field);if(value==null)return c;String style=value.optString("style");if(contains(STYLES,style))c.style=style;String palette=value.optString("palette");if(contains(PALETTES,palette))c.palette=palette;c.photoId=value.optString("photoId","");if(c.photoId.equals("null"))c.photoId="";c.text=value.optString("text","");c.brand=value.optBoolean("brand",true);c.invite=value.optBoolean("invite",true);JSONArray fields=value.optJSONArray("fields");if(fields!=null){c.fields.clear();for(int i=0;i<fields.length();i++){String field=fields.optString(i);if(contains(FIELDS,field))c.fields.add(field);}}return c;}
        JSONObject json(){return NativeApi.json("style",style,"palette",palette,"photoId",photoId.isEmpty()?JSONObject.NULL:photoId,"fields",new JSONArray(fields),"text",text,"brand",brand,"invite",invite);}
        private static boolean contains(String[] list,String key){for(String item:list)if(item.equals(key))return true;return false;}
    }
    static int[] size(String format){switch(format){case "1x1":return new int[]{1080,1080};case "4x5":return new int[]{1080,1350};case "9x16":return new int[]{1080,1920};default:return new int[]{1200,630};}}
    static Bitmap render(String format,Config config,JSONObject profile,Bitmap photo,String url,int divisor){
        int[] size=size(format);int width=Math.max(1,size[0]/divisor),height=Math.max(1,size[1]/divisor);Bitmap result=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);Canvas canvas=new Canvas(result);canvas.scale(1f/divisor,1f/divisor);draw(canvas,size[0],size[1],config,profile,photo,url);return result;
    }
    private static void draw(Canvas c,int w,int h,Config cfg,JSONObject profile,Bitmap image,String url){
        int accent=COLORS[index(PALETTES,cfg.palette)],paper=cfg.palette.equals("ink")?0xfff6f6f7:cfg.palette.equals("sea")?0xfff5f8fd:cfg.palette.equals("mint")?0xfff4faf7:cfg.palette.equals("milk")?0xfffbf7f2:0xfffaf7f5;
        boolean wide=w>h*1.3f;int white=Color.WHITE,dark=0xff1b1c20;Paint p=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
        c.drawColor(paper);RectF content=new RectF(0,0,w,h);float textX=64,textY,usable=w-128;boolean light=cfg.style.equals("card")||cfg.style.equals("type")||cfg.style.equals("minimal");
        if(cfg.style.equals("card")){
            if(wide){RectF left=new RectF(0,0,w*.42f,h);photo(c,image,left,accent);textX=w*.46f;textY=cfg.brand?106:64;usable=w-textX-58;}
            else{RectF top=new RectF(0,0,w,h*.55f);photo(c,image,top,accent);textX=64;textY=h*.59f;usable=w-128;}
        }else if(cfg.style.equals("type")){
            if(wide){photo(c,image,new RectF(w*.54f,0,w,h),accent);rect(c,new RectF(0,0,w*.56f,h),paper);usable=w*.48f;textY=cfg.brand?120:76;}
            else{photo(c,image,new RectF(0,0,w,h*.46f),accent);textY=h*.52f;}
        }else if(cfg.style.equals("minimal")){
            if(wide){photo(c,image,new RectF(w*.58f,40,w-40,h-40),accent);usable=w*.48f;textY=cfg.brand?120:76;}
            else{photo(c,image,new RectF(42,42,w-42,h*.47f),accent);textY=h*.53f;}
        }else{
            photo(c,image,content,accent);if(cfg.style.equals("night")){rect(c,content,0x77060a16);}gradient(c,wide?new RectF(0,0,w*.9f,h):new RectF(0,h*.22f,w,h),wide,false);
            textX=wide?64:72;textY=wide?h*.29f:h*.53f;usable=wide?w*.67f:w-144;light=false;
        }
        int fg=light?dark:white,muted=light?0xff777980:0xffe5e6e9;
        if(cfg.brand){label(c,"♥  erp.sex",textX,light?textY-49:wide?58:58,25,light?accent:white,true);}
        String name=profile.optString("displayName","");if(name.isEmpty())name="ERP";int nameSize=wide?54:72;
        textY=wrap(c,name,textX,textY,usable,nameSize,fg,true,2)+18;
        if(cfg.fields.contains("shine")){JSONObject shine=profile.optJSONObject("shine");if(shine!=null){String badge=shine.optInt("likes")>0?"★ "+UiStrings.t("喜欢前 ")+shine.optInt("likes")+"%":shine.optInt("superlikes")>0?"★ "+UiStrings.t("超级喜欢前 ")+shine.optInt("superlikes")+"%":"";if(!badge.isEmpty()){pill(c,badge,textX,textY,Math.min(usable,270),37,accent,white);textY+=54;}}}
        if(cfg.fields.contains("tagline")){String tagline=ProfileData.text(profile,"tagline");if(!tagline.isEmpty())textY=wrap(c,tagline,textX,textY,usable,wide?26:32,muted,false,2)+17;}
        if(!cfg.text.trim().isEmpty())textY=wrap(c,cfg.text.trim(),textX,textY,usable,wide?25:31,fg,false,2)+20;
        String chips=chips(profile,cfg);if(!chips.isEmpty())textY=wrap(c,chips,textX,textY,usable,wide?19:24,fg,false,wide?2:4)+18;
        String facts=facts(profile,cfg);if(!facts.isEmpty())wrap(c,facts,textX,textY,usable,wide?17:23,muted,false,wide?2:4);
        float footerY=h-(wide?54:94);if(!light&&cfg.style.equals("poster"))footerY=h-(wide?52:110);
        label(c,UiStrings.t("扫码看我的名片"),textX,footerY,wide?17:24,muted,false);label(c,"erp.sex",textX,footerY+(wide?20:31),wide?15:21,muted,false);
        if(cfg.fields.contains("qr"))qr(c,url,w-(wide?166:210),h-(wide?166:210),wide?128:166);
    }
    private static int index(String[] list,String value){for(int i=0;i<list.length;i++)if(list[i].equals(value))return i;return 0;}
    private static void rect(Canvas c,RectF rect,int color){Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(color);c.drawRect(rect,p);}
    private static void gradient(Canvas c,RectF area,boolean wide,boolean unused){Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setShader(wide?new LinearGradient(area.left,0,area.right,0,new int[]{0xdd08090e,0x8808090e,0x0008090e},null,Shader.TileMode.CLAMP):new LinearGradient(0,area.top,0,area.bottom,new int[]{0x0008090e,0xaa08090e,0xee08090e},null,Shader.TileMode.CLAMP));c.drawRect(area,p);}
    private static void photo(Canvas c,Bitmap bitmap,RectF destination,int fallback){if(bitmap==null||bitmap.isRecycled()){rect(c,destination,fallback);return;}float srcAspect=bitmap.getWidth()/(float)bitmap.getHeight(),dstAspect=destination.width()/destination.height();int sw=bitmap.getWidth(),sh=bitmap.getHeight();Rect crop;if(srcAspect>dstAspect){int width=Math.round(sh*dstAspect);crop=new Rect((sw-width)/2,0,(sw+width)/2,sh);}else{int height=Math.round(sw/dstAspect);int top=Math.max(0,Math.round((sh-height)*.4f));crop=new Rect(0,top,sw,Math.min(sh,top+height));}Paint p=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);c.drawBitmap(bitmap,crop,destination,p);}
    private static void label(Canvas c,String value,float x,float baseline,int size,int color,boolean bold){Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(color);p.setTextSize(size);p.setTypeface(bold?android.graphics.Typeface.create("sans-serif",android.graphics.Typeface.BOLD):android.graphics.Typeface.create("sans-serif",0));c.drawText(value,x,baseline,p);}
    private static float wrap(Canvas c,String value,float x,float baseline,float maxWidth,int size,int color,boolean bold,int maxLines){Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(color);p.setTextSize(size);p.setTypeface(android.graphics.Typeface.create("sans-serif",bold?1:0));StringBuilder line=new StringBuilder();int lines=0;for(int at=0;at<value.length();){int cp=value.codePointAt(at);String next=new String(Character.toChars(cp));at+=Character.charCount(cp);if(cp=='\n'||p.measureText(line+next)>maxWidth&&line.length()>0){c.drawText(line.toString(),x,baseline,p);baseline+=size*1.25f;line.setLength(0);lines++;if(lines>=maxLines)return baseline;}if(cp!='\n')line.append(next);}if(line.length()>0){c.drawText(line.toString(),x,baseline,p);baseline+=size*1.25f;}return baseline;}
    private static void pill(Canvas c,String value,float x,float y,float maxWidth,float height,int bg,int fg){Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(bg);float width=Math.min(maxWidth,Math.max(90,value.length()*23+24));c.drawRoundRect(new RectF(x,y-height+3,x+width,y+4),height/2,height/2,p);label(c,value,x+13,y-6,20,fg,true);}
    private static String chips(JSONObject profile,Config config){StringBuilder output=new StringBuilder();if(config.fields.contains("intents")){JSONArray values=profile.optJSONArray("intents");if(values!=null)for(int i=0;i<values.length();i++){String key=values.optString(i);if(!key.equals("erp"))append(output,UiStrings.t(key));}}if(config.fields.contains("tags")){JSONArray values=profile.optJSONArray("tags");if(values!=null)for(int i=0;i<values.length();i++){JSONObject tag=values.optJSONObject(i);if(tag!=null&&!tag.optString("category").matches("adult|xp"))append(output,"#"+tag.optString("name"));}}return output.toString();}
    private static String facts(JSONObject profile,Config config){StringBuilder output=new StringBuilder();JSONObject vrc=profile.optJSONObject("vrc");if(vrc==null)vrc=new JSONObject();if(config.fields.contains("platform"))appendArray(output,vrc.optJSONArray("platforms"));if(config.fields.contains("speech"))appendArray(output,vrc.optJSONArray("speech"));if(config.fields.contains("langs")){JSONArray langs=profile.optJSONArray("languages");if(langs!=null)for(int i=0;i<langs.length();i++){JSONObject language=langs.optJSONObject(i);if(language!=null)append(output,language.optString("code").toUpperCase(Locale.ROOT));}}if(config.fields.contains("time"))append(output,profile.optString("timezone"));if(config.fields.contains("avatar")){JSONArray models=profile.optJSONArray("models");if(models!=null&&models.length()>0)append(output,UiStrings.t("模型")+" "+models.length());}if(config.fields.contains("vrc")){JSONObject account=profile.optJSONObject("vrcAccount");if(account!=null)append(output,"VRChat "+account.optString("displayName"));}return output.toString();}
    private static void appendArray(StringBuilder output,JSONArray values){if(values!=null)for(int i=0;i<values.length();i++)append(output,values.optString(i));}
    private static void append(StringBuilder output,String value){if(value==null||value.isEmpty())return;if(output.length()>0)output.append(" · ");output.append(value);}
    private static void qr(Canvas c,String link,float x,float y,int size){try{QrCode code=QrCode.encodeText(link,QrCode.Ecc.MEDIUM);int modules=code.size;float cell=(size-16f)/modules;Paint p=new Paint(Paint.ANTI_ALIAS_FLAG);p.setColor(Color.WHITE);c.drawRoundRect(new RectF(x,y,x+size,y+size),10,10,p);p.setColor(Color.BLACK);for(int row=0;row<modules;row++)for(int col=0;col<modules;col++)if(code.getModule(col,row))c.drawRect(x+8+col*cell,y+8+row*cell,x+8+(col+1)*cell,y+8+(row+1)*cell,p);}catch(Exception ignored){}}
}
