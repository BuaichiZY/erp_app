package sex.erp.android;

/** Required website upload choices, independent from the native sheet's layout. */
final class ChatImagePolicy {
    static boolean valid(boolean file,String rating,boolean realPerson,boolean limited,boolean pledge,String kind,boolean adult){
        if(!file||!pledge)return false;
        if((realPerson||limited)&&!"general".equals(rating))return false;
        if("general".equals(rating)||"suggestive".equals(rating))return true;
        return "r18".equals(rating)&&adult&&("sexual".equals(kind)||"gore".equals(kind));
    }
}
