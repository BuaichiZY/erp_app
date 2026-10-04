package sex.erp.android;

import java.net.URI;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Small, testable rules for country routing and the mirror's public page format. */
final class UpdateDownloadPolicy {
    static boolean useMirror(String country){return "CN".equalsIgnoreCase(country==null?"":country.trim());}
    static boolean matches(String name,String tag){
        if(name==null||tag==null)return false;
        String version=tag.replaceFirst("^[vV]","");
        if(!version.matches("[0-9]+\\.[0-9]+\\.[0-9]+(?:[-_][A-Za-z0-9.-]+)?"))return false;
        return name.equalsIgnoreCase("ERP-Native-"+version+".apk")||name.equalsIgnoreCase("ERP-"+version+".apk");
    }
    static boolean trusted(String url){try{
        URI uri=new URI(url);String host=uri.getHost();
        if(!"https".equals(uri.getScheme())||host==null||uri.getUserInfo()!=null||(uri.getPort()!=-1&&uri.getPort()!=443))return false;
        host=host.toLowerCase(Locale.ROOT);
        for(String suffix:new String[]{"lanzouc.com","lanzouw.com","lanzoux.com","woozooo.com","lanrar.com","dmpdmp.com"})
            if(host.equals(suffix)||host.endsWith("."+suffix))return true;
        return false;
    }catch(Exception e){return false;}}
    static String capture(String html,String regex){Matcher m=Pattern.compile(regex,Pattern.DOTALL).matcher(html);if(!m.find())throw new IllegalArgumentException("Unsupported mirror page");return m.group(1);}
    static Map<String,String> form(String html){
        return form(html,new LinkedHashMap<>());
    }
    static Map<String,String> form(String html,Map<String,String> arguments){
        Map<String,String> variables=new LinkedHashMap<>();
        Matcher vars=Pattern.compile("\\bvar\\s+([A-Za-z_$][\\w$]*)\\s*=\\s*(?:'([^']*)'|\"([^\"]*)\"|(\\d+))").matcher(html);
        while(vars.find())if(!variables.containsKey(vars.group(1)))variables.put(vars.group(1),vars.group(2)!=null?vars.group(2):vars.group(3)!=null?vars.group(3):vars.group(4));
        variables.putAll(arguments);
        String body=capture(html,"\\bdata\\s*:\\s*\\{([^}]+)\\}");
        Map<String,String> result=new LinkedHashMap<>();
        Matcher fields=Pattern.compile("['\"]([A-Za-z0-9_]+)['\"]\\s*:\\s*(?:'([^']*)'|\"([^\"]*)\"|([A-Za-z_$][\\w$]*)|(\\d+))").matcher(body);
        while(fields.find()){
            String value=fields.group(2)!=null?fields.group(2):fields.group(3)!=null?fields.group(3):fields.group(5);
            if(value==null){if("pgs".equals(fields.group(4)))value="1";else value=variables.get(fields.group(4));}
            if(value==null)throw new IllegalArgumentException("Unsupported mirror field");
            result.put(fields.group(1),value);
        }
        if(result.isEmpty())throw new IllegalArgumentException("Empty mirror form");return result;
    }
}
