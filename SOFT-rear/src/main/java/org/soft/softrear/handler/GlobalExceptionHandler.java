package org.soft.softrear.handler;

import org.soft.softrear.pojo.ResponseMessage;
import org.springframework.http.HttpStatus;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

/**
 * 全局异常处理器
 */
@RestControllerAdvice // 这个注解表示这是一个全局的、针对 @RestController 的异常处理器
public class GlobalExceptionHandler {

    /**
     * 专门处理数据校验失败的异常
     * @param ex MethodArgumentNotValidException
     * @return 包含详细错误信息的 ResponseMessage
     */
    @ExceptionHandler(MethodArgumentNotValidException.class) // 指定要处理的异常类型
    @ResponseStatus(HttpStatus.BAD_REQUEST) // 指定响应的 HTTP 状态码为 400
    public ResponseMessage<Map<String, String>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        // 创建一个 Map 来存放字段名和对应的错误信息
        Map<String, String> errors = new HashMap<>();

        // 从异常对象中获取所有的字段错误
        ex.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField(); // 获取出错的字段名
            String errorMessage = error.getDefaultMessage(); // 获取我们在注解中定义的错误信息
            errors.put(fieldName, errorMessage);
        });

        // 使用我们自己的 ResponseMessage 结构返回错误信息
        // 你可以自定义 code，比如用 400 或者一个业务错误码
        return new ResponseMessage<>(400, "数据校验失败", errors);
    }

    @ExceptionHandler(RuntimeException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND) // 404 Not Found 是更合适的状态码
    public ResponseMessage<Void> handleRuntimeException(RuntimeException ex) {
        // ex.getMessage() 会返回我们抛出异常时传入的字符串，例如 "用户不存在，用户名: 123123"
        return new ResponseMessage<>(404, ex.getMessage(), null);
    }
}