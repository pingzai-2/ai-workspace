/**
 * ApiResponse 实现
 */

#include "ApiResponse.h"
#include <stdexcept>

using json = nlohmann::json;

std::string ApiResponse::success(const std::string& data)
{
    try {
        json response;
        response["code"] = CODE_SUCCESS;
        response["message"] = "Success";

        // 尝试解析data JSON
        try {
            json dataJson = json::parse(data);
            response["data"] = dataJson;
        } catch (const json::parse_error&) {
            // 如果解析失败，将data作为字符串
            response["data"] = data;
        }

        return response.dump();
    } catch (const std::exception& e) {
        // 发生错误时返回基本的成功响应
        json basicResponse;
        basicResponse["code"] = CODE_SUCCESS;
        basicResponse["message"] = "Success";
        basicResponse["data"] = data;
        return basicResponse.dump();
    }
}

std::string ApiResponse::successWithData(const nlohmann::json& dataJson)
{
    json response;
    response["code"] = CODE_SUCCESS;
    response["message"] = "Success";
    response["data"] = dataJson;
    return response.dump();
}

std::string ApiResponse::error(int code, const std::string& message)
{
    json response;
    response["code"] = code;
    response["message"] = message;
    return response.dump();
}

std::string ApiResponse::error(const std::string& message)
{
    return error(CODE_OPERATION_FAILED, message);
}

std::string ApiResponse::notImplemented(const std::string& feature)
{
    json response;
    response["code"] = CODE_NOT_IMPLEMENTED;
    response["message"] = "Feature not implemented: " + feature;
    return response.dump();
}

std::string ApiResponse::invalidParameter(const std::string& paramName, const std::string& message)
{
    json response;
    response["code"] = CODE_INVALID_PARAM;
    if (message.empty()) {
        response["message"] = "Invalid parameter: " + paramName;
    } else {
        response["message"] = message;
    }
    response["parameter"] = paramName;
    return response.dump();
}

std::string ApiResponse::deviceOffline()
{
    json response;
    response["code"] = CODE_DEVICE_OFFLINE;
    response["message"] = "Device is offline or not connected";
    return response.dump();
}

std::string ApiResponse::timeout()
{
    json response;
    response["code"] = CODE_TIMEOUT;
    response["message"] = "Operation timeout";
    return response.dump();
}

std::string ApiResponse::internalError(const std::string& errorMsg)
{
    json response;
    response["code"] = CODE_INTERNAL_ERROR;
    if (errorMsg.empty()) {
        response["message"] = "Internal server error";
    } else {
        response["message"] = "Internal error: " + errorMsg;
    }
    return response.dump();
}
