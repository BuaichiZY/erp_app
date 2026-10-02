package sex.erp.android;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import java.io.File;
import java.io.FileNotFoundException;

/** Read-only access to a generated PNG in the app cache for Android Sharesheet and clipboard. */
public final class ShareCardProvider extends ContentProvider {
    static final Uri URI=Uri.parse("content://sex.erp.android.share/card.png");
    private File file(Uri uri) throws FileNotFoundException {if(!URI.equals(uri))throw new FileNotFoundException("Unknown share image");return new File(getContext().getCacheDir(),"share-card.png");}
    @Override public boolean onCreate(){return true;}
    @Override public String getType(Uri uri){return URI.equals(uri)?"image/png":null;}
    @Override public ParcelFileDescriptor openFile(Uri uri,String mode)throws FileNotFoundException {if(!"r".equals(mode))throw new FileNotFoundException("Read only");return ParcelFileDescriptor.open(file(uri),ParcelFileDescriptor.MODE_READ_ONLY);}
    @Override public Cursor query(Uri uri,String[] projection,String selection,String[] selectionArgs,String sortOrder){try{File image=file(uri);MatrixCursor result=new MatrixCursor(new String[]{"_display_name","_size"});result.addRow(new Object[]{"ERP-card.png",image.length()});return result;}catch(FileNotFoundException ignored){return null;}}
    @Override public Uri insert(Uri uri,ContentValues values){throw new UnsupportedOperationException();}
    @Override public int update(Uri uri,ContentValues values,String selection,String[] selectionArgs){throw new UnsupportedOperationException();}
    @Override public int delete(Uri uri,String selection,String[] selectionArgs){throw new UnsupportedOperationException();}
}
