package com.postintime.media;

import java.io.InputStream;
import java.util.UUID;

public interface StorageService {

    String upload(String key, InputStream inputStream, long size, String contentType);

    void delete(String key);

    String getPublicUrl(String key);
}
