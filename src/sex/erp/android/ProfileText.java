package sex.erp.android;

import java.util.Map;

/** Read visible text from both legacy strings and the site's translated-text records. */
final class ProfileText {
    static String read(Object value){
        if(value instanceof CharSequence)return value.toString();
        if(!(value instanceof Map))return "";
        Map<?,?> record=(Map<?,?>)value;
        String translated=read(record.get("text"));
        return translated.trim().isEmpty()?read(record.get("originalText")):translated;
    }
}
