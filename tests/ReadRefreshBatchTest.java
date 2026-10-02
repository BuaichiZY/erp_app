package sex.erp.android;

public final class ReadRefreshBatchTest {
    private static int checks;
    private static void check(boolean condition) { if(!condition)throw new AssertionError("Check "+(checks+1));checks++; }
    public static void main(String[] args) {
        int[] calls={0};ReadRefreshBatch empty=new ReadRefreshBatch(()->calls[0]++);
        empty.release();check(calls[0]==1);
        ReadRefreshBatch batch=new ReadRefreshBatch(()->calls[0]++);
        batch.retain();batch.retain();batch.release();check(calls[0]==1);
        // A profile read starts comments/counters before its callback releases.
        batch.retain();batch.retain();batch.release();check(calls[0]==1);
        batch.release();check(calls[0]==1);batch.release();check(calls[0]==1);batch.release();check(calls[0]==2);
        boolean rejected=false;try{batch.release();}catch(IllegalStateException expected){rejected=true;}check(rejected);check(calls[0]==2);
        rejected=false;try{batch.retain();}catch(IllegalStateException expected){rejected=true;}check(rejected);
        ReadRefreshBatch failed=new ReadRefreshBatch(()->calls[0]++);failed.retain();failed.release();
        try{throw new IllegalArgumentException("Request failed");}catch(IllegalArgumentException expected){}finally{failed.release();}
        check(calls[0]==3);
        ReadRefreshBatch other=new ReadRefreshBatch(()->calls[0]++), concurrent=new ReadRefreshBatch(()->calls[0]++);
        other.retain();concurrent.retain();other.release();concurrent.release();other.release();check(calls[0]==4);concurrent.release();check(calls[0]==5);
        System.out.println("Refresh request completion checks passed: "+checks);
    }
}
