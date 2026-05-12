package org.soft.softrear.controller;

import org.soft.softrear.pojo.ResponseMessage;
import org.springframework.web.bind.annotation.*;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/external")
public class ExternalServiceController {
    
    // Python图像处理服务地址
    private static final String PYTHON_SERVICE_URL = "http://localhost:5000/process";
    
    // Dify本地服务地址
    private static final String DIFY_SERVICE_URL = "http://localhost:8000/api/v1/chat/completions";
    
    @PostMapping("/python/process-image")
    public ResponseMessage<Map<String, Object>> processImageWithPython(@RequestBody Map<String, Object> request) {
        try {
            String imagePath = (String) request.get("imagePath");
            String processType = (String) request.get("processType");
            
            // 这里调用Python服务
            // 实际项目中应该使用HttpClient调用
            String result = "Python处理结果: " + processType + " - " + imagePath;
            
            Map<String, Object> response = new HashMap<>();
            response.put("result", result);
            response.put("service", "python-image-processing");
            
            return ResponseMessage.success(response);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseMessage<>(500, "Python服务调用失败", null);
        }
    }
    
    @PostMapping("/dify/chat")
    public ResponseMessage<Map<String, Object>> chatWithDify(@RequestBody Map<String, Object> request) {
        try {
            String message = (String) request.get("message");
            String userId = (String) request.get("userId");
            
            // 这里调用Dify服务
            // 实际项目中应该使用HttpClient调用
            String response = "Dify回复: " + message;
            
            Map<String, Object> result = new HashMap<>();
            result.put("response", response);
            result.put("service", "dify-chat");
            result.put("userId", userId);
            
            return ResponseMessage.success(result);
        } catch (Exception e) {
            e.printStackTrace();
            return new ResponseMessage<>(500, "Dify服务调用失败", null);
        }
    }
    
    // 辅助方法：调用HTTP服务
    private String callHttpService(String serviceUrl, String requestBody) throws IOException {
        URL url = new URL(serviceUrl);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setDoOutput(true);
        
        conn.getOutputStream().write(requestBody.getBytes());
        
        BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        StringBuilder response = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            response.append(line);
        }
        reader.close();
        conn.disconnect();
        
        return response.toString();
    }
}
