package com.postintime;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class PostInTimeApplication {

    public static void main(String[] args) {
        SpringApplication.run(PostInTimeApplication.class, args);
    }
}
