package sex.erp.android;

import org.json.JSONObject;
import java.util.HashMap;

final class ProfileData {
    static String text(Object value){
        if(value instanceof JSONObject){JSONObject record=(JSONObject)value;HashMap<String,Object> copy=new HashMap<>();copy.put("text",record.opt("text"));copy.put("originalText",record.opt("originalText"));return ProfileText.read(copy);}
        return ProfileText.read(value);
    }
    static String text(JSONObject profile,String key){String visible=text(profile.opt(key+"I18n"));return visible.isEmpty()?text(profile.opt(key)):visible;}
    static String trust(String key){
        switch(key){case "visitor":return UiStrings.t("访客");case "new_user":return UiStrings.t("新玩家");case "user":return UiStrings.t("玩家");case "known_user":return UiStrings.t("熟悉玩家");case "trusted_user":return UiStrings.t("资深玩家");case "nuisance":return UiStrings.t("受限玩家");default:return "";}
    }
}
