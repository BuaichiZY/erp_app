package sex.erp.android;

import java.net.URLDecoder;
import java.net.URLEncoder;
import java.util.*;

/** Public website filter names and allowed values; drafts are separate from applied filters. */
final class DiscoverFilters {
    static final String[] KEYS={"intents","platforms","languages","speech","modelGender","voice"};
    static final String[] TITLES={"意向","平台","语言","说话方式","模型性别呈现","声音"};
    static final String[][] VALUES={
        {"friends","romance","erp","activity","creative"},
        {"pcvr","quest","mobile","desktop"},
        {"zh","yue","ja","ko","en","th","vi","id","ms","tl","hi","ru","es","fr","de","pt"},
        {"voice","mute","sign","gesture"},
        {"masculine","feminine","androgynous","nonhuman","other"},
        {"male","female","neutral","voice_changer","mute"}
    };
    static final String[][] LABELS={
        {"交友","恋爱","ERP","活动","创作"},
        {"PC VR","Quest","手机","桌面"},
        {"中文","粤语","日文","韩文","英文","泰文","越南文","印尼文","马来文","菲律宾文","印地文","俄文","西班牙文","法文","德文","葡萄牙文"},
        {"开麦","静音","手语","表情／肢体语言"},
        {"男性化","女性化","中性","非人","其他"},
        {"男声","女声","中性","变声器","静音"}
    };
    static final String[] FLAGS={"fullBody","hasVoiceCard","onlineNow","nearTimezone"};
    private final Map<String,TreeSet<String>> groups=new LinkedHashMap<>();
    private final Set<String> flags=new HashSet<>();
    DiscoverFilters(){for(String key:KEYS)groups.put(key,new TreeSet<>());}
    DiscoverFilters copy(){DiscoverFilters result=new DiscoverFilters();for(String key:KEYS)result.groups.get(key).addAll(groups.get(key));result.flags.addAll(flags);return result;}
    void clear(){for(Set<String> group:groups.values())group.clear();flags.clear();}
    boolean selected(String key,String value){Set<String> group=groups.get(key);return group!=null&&group.contains(value);}
    void select(String key,String value,boolean on){int index=Arrays.asList(KEYS).indexOf(key);if(index<0||!Arrays.asList(VALUES[index]).contains(value))return;if(on)groups.get(key).add(value);else groups.get(key).remove(value);}
    boolean flag(String key){return flags.contains(key);}
    void flag(String key,boolean on){if(!Arrays.asList(FLAGS).contains(key))return;if(on)flags.add(key);else flags.remove(key);}
    int count(boolean presence){int count=0;for(Set<String> group:groups.values())if(!group.isEmpty())count++;for(String key:flags)if(presence||!key.equals("onlineNow"))count++;return count;}
    String query(boolean presence){StringBuilder result=new StringBuilder();for(String key:KEYS)if(!groups.get(key).isEmpty())result.append('&').append(key).append('=').append(encode(String.join(",",groups.get(key))));for(String key:FLAGS)if(flag(key)&&(presence||!key.equals("onlineNow")))result.append('&').append(key).append("=true");return result.toString();}
    static DiscoverFilters parse(String query){DiscoverFilters result=new DiscoverFilters();for(String part:query.split("&")){String[] pair=part.split("=",2);if(pair.length!=2)continue;String value;try{value=URLDecoder.decode(pair[1],"UTF-8");}catch(Exception ignored){continue;}if(Arrays.asList(FLAGS).contains(pair[0]))result.flag(pair[0],"true".equals(value));else for(String entry:value.split(","))result.select(pair[0],entry,true);}return result;}
    private static String encode(String value){try{return URLEncoder.encode(value,"UTF-8");}catch(Exception e){throw new IllegalStateException(e);}}
}
