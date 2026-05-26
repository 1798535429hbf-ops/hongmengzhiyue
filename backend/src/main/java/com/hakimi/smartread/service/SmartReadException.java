package com.hakimi.smartread.service;

import org.springframework.http.HttpStatus;

public class SmartReadException extends RuntimeException {
    private final HttpStatus status;

    public SmartReadException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus status() {
        return status;
    }

    public static SmartReadException badRequest(String message) {
        return new SmartReadException(HttpStatus.BAD_REQUEST, message);
    }

    public static SmartReadException notFound(String message) {
        return new SmartReadException(HttpStatus.NOT_FOUND, message);
    }

    public static SmartReadException upstream(String message) {
        return new SmartReadException(HttpStatus.BAD_GATEWAY, message);
    }
}
