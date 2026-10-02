package sex.erp.android;

import java.util.Locale;

/** Resolve explicit app preferences separately from the device's locale list. */
final class LanguageRules {
    static final String[] OPTIONS={"auto","zh-Hans","zh-Hant","ja","en","ko"};
    static String supported(String tag){
        if(tag==null)return "";Locale locale=Locale.forLanguageTag(tag.replace('_','-'));
        String language=locale.getLanguage();
        if("zh".equals(language)){
            if("Hant".equals(locale.getScript()))return "zh-Hant";
            if("Hans".equals(locale.getScript()))return "zh-Hans";
            String country=locale.getCountry();return "TW".equals(country)||"HK".equals(country)||"MO".equals(country)?"zh-Hant":"zh-Hans";
        }
        return "ja".equals(language)||"en".equals(language)||"ko".equals(language)?language:"";
    }
    static String preference(String choice){for(String option:OPTIONS)if(option.equals(choice))return option;return "auto";}
    static String resolve(String preference,String... deviceTags){
        String choice=preference(preference);if(!"auto".equals(choice))return choice;
        if(deviceTags!=null)for(String tag:deviceTags){String supported=supported(tag);if(!supported.isEmpty())return supported;}
        return "en";
    }
    static String name(String language){switch(language){case "zh-Hans":return "简体中文";case "zh-Hant":return "繁體中文";case "ja":return "日本語";case "ko":return "한국어";default:return "English";}}
}
