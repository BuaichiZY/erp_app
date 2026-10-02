package sex.erp.android;

public final class PostRulesTest {
    private static int checks;
    private static void eq(Object value,Object expected){checks++;if(!value.equals(expected))throw new AssertionError(value+" != "+expected);}
    private static String valid(String title,String body,String category,String rating,String kind,boolean restricted,boolean pledge){return PostRules.validate(title,body,category,rating,kind,restricted,pledge,80,2000);}
    private static String repeat(String s,int n){StringBuilder result=new StringBuilder();for(int i=0;i<n;i++)result.append(s);return result.toString();}
    public static void main(String[] args){
        eq(PostRules.endpoint("mix","","",false,false,""),"/posts?sort=mix");
        eq(PostRules.endpoint("bogus","bogus","",false,true,""),"/posts?sort=mix&hideAds=1");
        eq(PostRules.endpoint("new","photo","",true,true,""),"/posts?sort=new&category=photo&mine=1");
        eq(PostRules.endpoint("hot","ad","",false,true,""),"/posts?sort=hot&category=ad");
        eq(PostRules.endpoint("new","","",true,true,""),"/posts?sort=new&mine=1");
        eq(PostRules.endpoint("mix",""," a&b + ",false,false,"abc+/="),"/posts?sort=mix&q=a%26b+%2B&cursor=abc%2B%2F%3D");
        eq(PostRules.endpoint("new","","\n\t",false,false,null),"/posts?sort=new");
        eq(valid(" ","hello","daily","general","",false,true),"请填写标题");
        eq(valid("标题","","daily","general","",false,true),"");
        eq(valid(repeat("🌸",80),"","daily","general","",false,true),"");
        eq(valid(repeat("🌸",81),"","daily","general","",false,true),"标题过长");
        eq(valid("标题",repeat("🌸",2000),"daily","general","",false,true),"");
        eq(valid("标题",repeat("🌸",2001),"daily","general","",false,true),"内容过长");
        eq(valid("标题","","daily","","",false,true),"请选择内容分级");
        eq(valid("标题","","erp","general","",false,true),"角色扮演分类请选择擦边或 R18 分级");
        eq(valid("标题","","erp","general","",true,true),"");
        eq(valid("标题","","daily","suggestive","",true,true),"当前账号仅支持全年龄内容");
        eq(valid("标题","","daily","r18","",false,true),"请选择 R18 内容类型");
        eq(valid("标题","","daily","r18","sexual",false,true),"");
        eq(valid("标题","","daily","r18","gore",false,true),"");
        eq(valid("标题","","daily","general","",false,false),"请先确认遵守社区规则");
        eq(PostRules.canComment("\n\t "),false);eq(PostRules.canComment(null),false);
        eq(PostRules.canComment(" 你好 "),true);eq(PostRules.canComment(repeat("🌸",500)),true);eq(PostRules.canComment(repeat("🌸",501)),false);
        System.out.println("Post rules: "+checks+" checks passed");
    }
}
