/**
 * BasePage 实现
 */

#include "BasePage.h"

BasePage::BasePage(DataManager* dataManager)
    : m_dataManager(dataManager)
{
}

std::string BasePage::buildSuccess(const std::string& data) const
{
    return ApiResponse::success(data);
}

std::string BasePage::buildSuccessWithData(const nlohmann::json& dataJson) const
{
    return ApiResponse::successWithData(dataJson);
}

std::string BasePage::buildError(const std::string& message) const
{
    return ApiResponse::error(message);
}

std::string BasePage::buildNotImplemented(const std::string& feature) const
{
    return ApiResponse::notImplemented(feature);
}

std::string BasePage::buildDeviceOffline() const
{
    return ApiResponse::deviceOffline();
}

std::string BasePage::buildInvalidParameter(const std::string& paramName, const std::string& message) const
{
    return ApiResponse::invalidParameter(paramName, message);
}
