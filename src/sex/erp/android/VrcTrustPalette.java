package sex.erp.android;

/** Badge colors used by the website for each VRChat trust tier. */
final class VrcTrustPalette {
    static int background(String key){
        switch(key){case "visitor":return 0xffcccccc;case "new_user":return 0xff1778ff;case "user":return 0xff2bcf5c;case "known_user":return 0xffff7b42;case "trusted_user":return 0xff8143e6;case "nuisance":return 0xff782f2f;default:return 0xff8245e7;}
    }
    static int foreground(String key){return "visitor".equals(key)||"user".equals(key)||"known_user".equals(key)?0xff111827:0xffffffff;}
}
