/**
 * ApiResponse - 统一的API响应构建器
 *
 * 提供标准化的API响应格式，消除代码中返回空"{}"的问题
 */

#ifndef APIRESPONSE_H
#define APIRESPONSE_H

#include <string>
#include <nlohmann/json.hpp>

class ApiResponse {
public:
    /**
     * @brief 构建成功响应
     * @param data 响应数据（JSON字符串）
     * @return 完整的API响应JSON字符串
     */
    static std::string success(const std::string& data = "{}");

    /**
     * @brief 构建带数据字段的完整成功响应
     * @param dataJson 数据字段的JSON对象
     * @return 完整的API响应JSON字符串
     */
    static std::string successWithData(const nlohmann::json& dataJson);

    /**
     * @brief 构建错误响应
     * @param code 错误码（参考ApiCode枚举）
     * @param message 错误描述信息
     * @return 错误响应JSON字符串
     */
    static std::string error(int code, const std::string& message);

    /**
     * @brief 构建错误响应（使用默认错误码）
     * @param message 错误描述信息
     * @return 错误响应JSON字符串
     */
    static std::string error(const std::string& message);

    /**
     * @brief 构建功能未实现响应
     * @param feature 未实现的功能名称
     * @return 未实现响应JSON字符串
     */
    static std::string notImplemented(const std::string& feature);

    /**
     * @brief 构建参数错误响应
     * @param paramName 参数名称
     * @param message 错误描述
     * @return 参数错误响应JSON字符串
     */
    static std::string invalidParameter(const std::string& paramName, const std::string& message = "");

    /**
     * @brief 构建设备离线响应
     * @return 设备离线响应JSON字符串
     */
    static std::string deviceOffline();

    /**
     * @brief 构建操作超时响应
     * @return 超时响应JSON字符串
     */
    static std::string timeout();

    /**
     * @brief 构建内部错误响应
     * @param errorMsg 错误详情
     * @return 内部错误响应JSON字符串
     */
    static std::string internalError(const std::string& errorMsg = "");

private:
    // API码定义（与GlobalDefine.h中的ApiCode保持一致）
    static constexpr int CODE_SUCCESS = 0;
    static constexpr int CODE_INVALID_PARAM = 1001;
    static constexpr int CODE_DEVICE_OFFLINE = 1002;
    static constexpr int CODE_OPERATION_FAILED = 1003;
    static constexpr int CODE_TIMEOUT = 1004;
    static constexpr int CODE_INTERNAL_ERROR = 1005;
    static constexpr int CODE_NOT_IMPLEMENTED = 1006;
};

#endif // APIRESPONSE_H
