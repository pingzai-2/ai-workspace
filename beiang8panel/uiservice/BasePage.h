/**
 * BasePage - UI服务基类
 *
 * 提取所有 *Page 类的公共模式：
 * - DataManager引用管理
 * - 统一的响应构建
 * - 错误处理模式
 */

#ifndef BASEPAGE_H
#define BASEPAGE_H

#include "DataManager.h"
#include "common/ApiResponse.h"
#include <string>

/**
 * @brief UI服务页面基类
 *
 * 所有 UIService Page 类的基类，提供：
 * - 数据管理器访问
 * - 统一的响应构建
 * - 常用错误处理
 */
class BasePage {
public:
    /**
     * @brief 构造函数
     * @param dataManager 数据管理器指针
     */
    explicit BasePage(DataManager* dataManager);

    /**
     * @brief 虚析构函数
     */
    virtual ~BasePage() = default;

protected:
    /**
     * @brief 获取数据管理器
     * @return DataManager* 数据管理器指针
     */
    DataManager* dataManager() const { return m_dataManager; }

    /**
     * @brief 构建成功响应
     * @param data 响应数据JSON字符串
     * @return std::string 完整的API响应JSON字符串
     */
    std::string buildSuccess(const std::string& data = "{}") const;

    /**
     * @brief 构建成功响应（带JSON对象）
     * @param dataJson 响应数据JSON对象
     * @return std::string 完整的API响应JSON字符串
     */
    std::string buildSuccessWithData(const nlohmann::json& dataJson) const;

    /**
     * @brief 构建错误响应
     * @param message 错误描述信息
     * @return std::string 错误响应JSON字符串
     */
    std::string buildError(const std::string& message) const;

    /**
     * @brief 构建功能未实现响应
     * @param feature 功能名称
     * @return std::string 未实现响应JSON字符串
     */
    std::string buildNotImplemented(const std::string& feature) const;

    /**
     * @brief 构建设备离线响应
     * @return std::string 设备离线响应JSON字符串
     */
    std::string buildDeviceOffline() const;

    /**
     * @brief 构建参数错误响应
     * @param paramName 参数名称
     * @param message 错误描述
     * @return std::string 参数错误响应JSON字符串
     */
    std::string buildInvalidParameter(const std::string& paramName, const std::string& message = "") const;

private:
    DataManager* m_dataManager;
};

#endif // BASEPAGE_H
