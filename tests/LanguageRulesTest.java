package sex.erp.android;

import java.util.HashMap;
import java.util.Map;

public final class LanguageRulesTest {
    private static int checks;
    private static void expect(String actual,String expected){checks++;if(!expected.equals(actual))throw new AssertionError(actual+" != "+expected);}
    public static void main(String[] args){
        expect(LanguageRules.resolve("auto","zh-CN"),"zh-Hans");
        expect(LanguageRules.resolve("auto","zh-TW"),"zh-Hant");
        expect(LanguageRules.resolve("auto","zh-HK"),"zh-Hant");
        expect(LanguageRules.resolve("auto","zh-Hant-SG"),"zh-Hant");
        expect(LanguageRules.resolve("auto","ja-JP"),"ja");
        expect(LanguageRules.resolve("auto","ko-KR"),"ko");
        expect(LanguageRules.resolve("auto","en-GB"),"en");
        expect(LanguageRules.resolve("auto","de-DE","ja-JP"),"ja");
        expect(LanguageRules.resolve("auto","de-DE"),"en");
        expect(LanguageRules.resolve("ko","en-US"),"ko");
        expect(LanguageRules.resolve("bad-value","zh-TW"),"zh-Hant");
        Map<String,String> english=new HashMap<>();english.put("设置","Settings");
        UiStrings.install("en",english);expect(UiStrings.t("设置"),"Settings");
        expect(UiStrings.t("用户发布的原文"),"用户发布的原文");
        UiStrings.install("zh-Hans",new HashMap<>());expect(UiStrings.t("设置"),"设置");
        System.out.println("Language selection and text fallback: "+checks+" checks passed");
    }
}
