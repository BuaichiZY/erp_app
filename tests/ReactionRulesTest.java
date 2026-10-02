package sex.erp.android;

public final class ReactionRulesTest {
    private static int checks;
    private static void check(String expected,boolean existing,boolean mine,int mineCount,int kinds){String actual=ReactionRules.pick(existing,mine,mineCount,kinds);if(!expected.equals(actual))throw new AssertionError(actual+" != "+expected);checks++;}
    public static void main(String[] args){
        check("add",false,false,0,0);check("add",false,false,2,19);check("add",true,false,0,20);check("add",true,false,2,20);
        check("full",false,false,0,20);check("full",false,false,2,21);check("limit",true,false,3,20);check("limit",false,false,3,0);
        check("none",true,true,1,1);check("none",true,true,3,20);check("none",true,true,4,21);check("limit",false,false,4,21);
        System.out.println("Inline reaction rule checks passed: "+checks);
    }
}
