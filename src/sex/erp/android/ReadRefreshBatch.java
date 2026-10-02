package sex.erp.android;

/** UI-thread request scope: nested reads join before their parent completes. */
final class ReadRefreshBatch {
    private int pending = 1;
    private boolean finished;
    private final Runnable complete;
    ReadRefreshBatch(Runnable complete) { this.complete = complete; }
    void retain() {
        if (finished) throw new IllegalStateException("Refresh already finished");
        pending++;
    }
    void release() {
        if (finished || pending <= 0) throw new IllegalStateException("Unbalanced refresh");
        if (--pending == 0) { finished = true; complete.run(); }
    }
}
