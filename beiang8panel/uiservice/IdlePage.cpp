/**
 * 待机页面API实现
 */

#include "IdlePage.h"
#include "gateways/BeiAng4CPGateway.h"
#include "DataManager.h"
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>
#include <cmath> // for std::lround

namespace {

// ========== PM2.5 空气质量等级（待机页面室内外空气评价） ==========
// 分级标准：优 0~35 / 良 36~75 / 中 76~150 / 差 151~999
enum class PM25Level {
    Excellent,  // 优
    Good,       // 良
    Moderate,   // 中
    Bad         // 差
};

// 根据PM2.5数值（μg/m³）判定空气质量等级
PM25Level gradePM25(int pm25) {
    if (pm25 <= 35)  return PM25Level::Excellent;
    if (pm25 <= 75)  return PM25Level::Good;
    if (pm25 <= 150) return PM25Level::Moderate;
    return PM25Level::Bad;
}

// 等级转中文字符串（前端展示用）
const char* pm25LevelToString(PM25Level level) {
    switch (level) {
        case PM25Level::Excellent: return "优";
        case PM25Level::Good:      return "良";
        case PM25Level::Moderate:  return "中";
        case PM25Level::Bad:       return "差";
    }
    return "";
}

// 根据室内外PM2.5等级生成待机页面空气评价提醒文案。
// 规则：室外为"优/良"时不提醒（返回空串）；其余按室内(优/良|中|差) × 室外(中|差) 给出建议。
std::string buildAirQualityReminder(PM25Level indoor, PM25Level outdoor) {
    // 室外空气质量优良时不做提醒
    if (outdoor == PM25Level::Excellent || outdoor == PM25Level::Good) {
        return "";
    }

    const bool outdoorBad = (outdoor == PM25Level::Bad);

    // 室内：优/良
    if (indoor == PM25Level::Excellent || indoor == PM25Level::Good) {
        return outdoorBad
            ? "室内空气质量优良，室外空气质量较差，建议减少室外活动"
            : "室内空气质量优良，室外空气质量一般，建议减少室外活动";
    }

    // 室内：中
    if (indoor == PM25Level::Moderate) {
        return outdoorBad
            ? "室内空气质量一般，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动"
            : "室内空气质量一般，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动";
    }

    // 室内：差
    return outdoorBad
        ? "室内空气质量较差，室外空气质量较差，建议开启超净提升净化效率，并减少室外活动"
        : "室内空气质量较差，室外空气质量一般，建议开启超净提升净化效率，并减少室外活动";
}

} // namespace

IdlePage::IdlePage(DataManager* dataManager)
    : BasePage(dataManager)
{
}

std::string IdlePage::getIdlePageData() {
    // TODO: 获取待机页面数据
    return buildNotImplemented("getIdlePageData");
}

std::string IdlePage::getEnvironmentData() {
    try {
        // 环境数据随设备主数据周期采集，此处纯读 m_gatewayData 缓存
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();
        auto& ra1 = gatewayData.getRA1Sensor();   // 室内回风
        auto& oa = gatewayData.getOASensor();      // 室外新风
        auto& sa = gatewayData.getSASensor();      // 送风
        auto& airQualityMetrics = gatewayData.getAirQuality();

        // 构建JSON响应
        nlohmann::json response;
        response["code"] = 200;
        response["message"] = "Success";

        nlohmann::json data;

        // 数值统一取整为整数输出（前端展示无小数部分；
        // 同时消除 float 序列化产生的精度尾巴，如 16.100000381469727）
        auto toInt = [](float v) -> int {
            return static_cast<int>(std::lround(v));
        };

        // 室内回风数据（RA）
        nlohmann::json indoorReturnAir;
        indoorReturnAir["temperature"] = toInt(ra1.temperature);
        indoorReturnAir["humidity"] = toInt(ra1.humidity);
        indoorReturnAir["pm25"] = toInt(ra1.pm25);
        indoorReturnAir["co2"] = toInt(ra1.co2);
        data["indoorReturnAir"] = indoorReturnAir;

        // 室外新风数据（OA）
        nlohmann::json outdoorAir;
        outdoorAir["temperature"] = toInt(oa.temperature);
        outdoorAir["humidity"] = toInt(oa.humidity);
        outdoorAir["pm25"] = toInt(oa.pm25);
        outdoorAir["co2"] = toInt(oa.co2);
        data["outdoorAir"] = outdoorAir;

        // 送风数据（SA）
        nlohmann::json supplyAir;
        supplyAir["temperature"] = toInt(sa.temperature);
        supplyAir["humidity"] = toInt(sa.humidity);
        supplyAir["pm25"] = toInt(sa.pm25);
        supplyAir["co2"] = toInt(sa.co2);
        data["supplyAir"] = supplyAir;

        // 空气质量数据（TVOC和甲醛）
        nlohmann::json airQuality;
        airQuality["tvoc"] = toInt(airQualityMetrics.tvoc);
        airQuality["formaldehyde"] = toInt(airQualityMetrics.formaldehyde);
        data["airQuality"] = airQuality;

        response["data"] = data;

        spdlog::debug("[IdlePage] Environment data: RA={:.1f}°C/{:.1f}%, OA={:.1f}°C/{:.1f}%, SA={:.1f}°C/{:.1f}%, TVOC={:.1f}, HCHO={:.3f}",
                      ra1.temperature, ra1.humidity,
                      oa.temperature, oa.humidity,
                      sa.temperature, sa.humidity,
                      airQualityMetrics.tvoc, airQualityMetrics.formaldehyde);

        return response.dump();

    } catch (const std::exception& e) {
        spdlog::error("[IdlePage] Exception in getEnvironmentData: {}", e.what());
        return buildError(std::string("Internal server error: ") + e.what());
    }
}

std::string IdlePage::getAirQualityReminder() {
    try {
        // 环境数据随设备主数据周期采集，此处纯读 m_gatewayData 缓存
        DataManager::DataLock dataLock(*dataManager());
        auto& gatewayData = dataManager()->getGatewayData();

        // 数值统一取整为整数输出（与 getEnvironmentData 保持一致）
        auto toInt = [](float v) -> int {
            return static_cast<int>(std::lround(v));
        };

        // 室内PM2.5来源于200FH（RA1），室外PM2.5来源于2013H（OA）
        int indoorPM25  = toInt(gatewayData.getRA1Sensor().pm25);
        int outdoorPM25 = toInt(gatewayData.getOASensor().pm25);

        PM25Level indoorLevel  = gradePM25(indoorPM25);
        PM25Level outdoorLevel = gradePM25(outdoorPM25);
        std::string reminder   = buildAirQualityReminder(indoorLevel, outdoorLevel);

        // 构建JSON响应
        nlohmann::json data;
        data["indoorPM25"]   = indoorPM25;
        data["outdoorPM25"]  = outdoorPM25;
        data["indoorLevel"]  = pm25LevelToString(indoorLevel);
        data["outdoorLevel"] = pm25LevelToString(outdoorLevel);
        data["reminder"]     = reminder;

        nlohmann::json response;
        response["code"] = 200;
        response["message"] = "Success";
        response["data"] = data;

        spdlog::debug("[IdlePage] Air quality reminder: indoor PM2.5={} ({}), outdoor PM2.5={} ({}) => \"{}\"",
                      indoorPM25, pm25LevelToString(indoorLevel),
                      outdoorPM25, pm25LevelToString(outdoorLevel), reminder);

        return response.dump();

    } catch (const std::exception& e) {
        spdlog::error("[IdlePage] Exception in getAirQualityReminder: {}", e.what());
        return buildError(std::string("Internal server error: ") + e.what());
    }
}

std::string IdlePage::wakeUp() {
    // TODO: 唤醒设备
    return buildNotImplemented("wakeUp");
}
