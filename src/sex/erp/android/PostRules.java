package sex.erp.android;

import java.net.URLEncoder;

final class PostRules {
    static final String[] CATEGORIES={"daily","dance","photo","event","hangout","creative","erp","other","ad","club"};
    static final String[] LABELS={"日常分享","舞伴","合拍","活动","一起玩","创作合作","ERP","其他","广告","社团宣传"};
    static final String[] SORTS={"mix","new","hot"},SORT_LABELS={"综合","最新","热门"};
    static String category(String code){for(int i=0;i<CATEGORIES.length;i++)if(CATEGORIES[i].equals(code))return UiStrings.t(LABELS[i]);return UiStrings.t("所有分类");}
    private static String encode(String raw){try{return URLEncoder.encode(raw,"UTF-8");}catch(Exception e){return "";}}
    static String endpoint(String sort,String category,String search,boolean mine,boolean hideAds,String cursor){
        boolean validSort=false;for(String value:SORTS)if(value.equals(sort))validSort=true;
        String path="/posts?sort="+(validSort?sort:"mix");boolean validCategory=false;for(String value:CATEGORIES)if(value.equals(category))validCategory=true;
        if(validCategory)path+="&category="+category;if(mine)path+="&mine=1";if(hideAds&&!mine&&!validCategory)path+="&hideAds=1";
        if(search!=null&&!search.trim().isEmpty())path+="&q="+encode(search.trim());if(cursor!=null&&!cursor.isEmpty())path+="&cursor="+encode(cursor);return path;
    }
    static String validate(String title,String body,String category,String rating,String kind,boolean restricted,boolean confirmed,int titleMax,int bodyMax){
        if(title==null||title.trim().isEmpty())return UiStrings.t("请填写标题");
        if(title.trim().codePointCount(0,title.trim().length())>titleMax)return UiStrings.t("标题过长");
        if(body!=null&&body.trim().codePointCount(0,body.trim().length())>bodyMax)return UiStrings.t("内容过长");
        if(!rating.equals("general")&&!rating.equals("suggestive")&&!rating.equals("r18"))return UiStrings.t("请选择内容分级");
        if(restricted&&!rating.equals("general"))return UiStrings.t("当前账号仅支持全年龄内容");
        if(!restricted&&category.equals("erp")&&rating.equals("general"))return UiStrings.t("角色扮演分类请选择擦边或 R18 分级");
        if(rating.equals("r18")&&!kind.equals("sexual")&&!kind.equals("gore"))return UiStrings.t("请选择 R18 内容类型");
        if(!confirmed)return UiStrings.t("请先确认遵守社区规则");return "";
    }
    static boolean canComment(String body){return body!=null&&!body.trim().isEmpty()&&body.trim().codePointCount(0,body.trim().length())<=500;}
    static String commentCursor(Object value){return value instanceof String?(String)value:"";}
}
