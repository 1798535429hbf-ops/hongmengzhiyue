package com.hakimi.smartread.service;

import java.math.BigDecimal;
import java.util.Collection;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

public final class Payloads {
    private Payloads() {
    }

    public static String text(Map<String, Object> payload, String key, String fallback) {
        Object value = payload.get(key);
        if (value == null) {
            return fallback;
        }
        if (value instanceof Collection<?> values) {
            return values.stream().map(Objects::toString).collect(Collectors.joining(","));
        }
        return value.toString();
    }

    public static String text(Map<String, Object> payload, String key) {
        String value = text(payload, key, "");
        if (value.isBlank()) {
            throw SmartReadException.badRequest("缺少参数：" + key);
        }
        return value;
    }

    public static long number(Map<String, Object> payload, String key, long fallback) {
        Object value = payload.get(key);
        if (value == null) {
            value = payload.get(toCamel(key));
        }
        if (value == null) {
            return fallback;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        return Long.parseLong(value.toString());
    }

    public static int integer(Map<String, Object> payload, String key, int fallback) {
        return (int) number(payload, key, fallback);
    }

    public static BigDecimal decimal(Map<String, Object> payload, String key, BigDecimal fallback) {
        Object value = payload.get(key);
        if (value == null) {
            return fallback;
        }
        if (value instanceof BigDecimal decimal) {
            return decimal;
        }
        if (value instanceof Number number) {
            return BigDecimal.valueOf(number.doubleValue());
        }
        return new BigDecimal(value.toString());
    }

    public static boolean bool(Map<String, Object> payload, String key, boolean fallback) {
        Object value = payload.get(key);
        if (value == null) {
            return fallback;
        }
        if (value instanceof Boolean bool) {
            return bool;
        }
        return Boolean.parseBoolean(value.toString());
    }

    private static String toCamel(String key) {
        int index = key.indexOf('_');
        if (index < 0 || index == key.length() - 1) {
            return key;
        }
        return key.substring(0, index) + Character.toUpperCase(key.charAt(index + 1)) + key.substring(index + 2);
    }
}
