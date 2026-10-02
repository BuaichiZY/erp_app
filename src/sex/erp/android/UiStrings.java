package sex.erp.android;

import java.util.Collections;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/** Translate authored interface literals only. User text is never passed here. */
final class UiStrings {
    private static final class Catalog {
        final String language;final Map<String,String> translations;
        Catalog(String language,Map<String,String> translations){this.language=language;this.translations=Collections.unmodifiableMap(new HashMap<>(translations));}
    }
    private static volatile Catalog catalog=new Catalog("zh-Hans",Collections.emptyMap());
    static void install(String language,Map<String,String> translations){catalog=new Catalog(language,translations);}
    static String t(String literal){String value=catalog.translations.get(literal);return value==null?literal:value;}
    static String[] list(String[] literals){String[] result=new String[literals.length];for(int i=0;i<result.length;i++)result[i]=t(literals[i]);return result;}
    static String language(){return catalog.language;}
    static Locale locale(){return Locale.forLanguageTag(language());}
}
