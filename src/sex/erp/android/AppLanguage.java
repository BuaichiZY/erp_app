package sex.erp.android;

import android.content.Context;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.os.LocaleList;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

final class AppLanguage {
    static String detect(String preference){
        LocaleList locales=Resources.getSystem().getConfiguration().getLocales();String[] tags=new String[locales.size()];
        for(int i=0;i<tags.length;i++)tags[i]=locales.get(i).toLanguageTag();return LanguageRules.resolve(preference,tags);
    }
    static void apply(Context context,String language){
        Map<String,String> translations=new HashMap<>();
        if(!"zh-Hans".equals(language))try{
            String name="ui_"+language.toLowerCase(java.util.Locale.ROOT).replace('-','_');
            int id=context.getResources().getIdentifier(name,"raw",context.getPackageName());
            try(InputStream in=context.getResources().openRawResource(id);ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] buffer=new byte[4096];int n;while((n=in.read(buffer))!=-1)out.write(buffer,0,n);
                JSONObject catalog=new JSONObject(out.toString("UTF-8"));for(Iterator<String> keys=catalog.keys();keys.hasNext();){String key=keys.next();translations.put(key,catalog.getString(key));}
            }
        }catch(Exception error){throw new IllegalStateException("Unable to load UI language: "+language,error);}
        UiStrings.install(language,translations);
    }
    static Context context(Context base){Configuration config=new Configuration(base.getResources().getConfiguration());config.setLocales(LocaleList.forLanguageTags(UiStrings.language()));return base.createConfigurationContext(config);}
    private AppLanguage(){}
}
