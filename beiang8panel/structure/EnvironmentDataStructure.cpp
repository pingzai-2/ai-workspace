/**
 * 环境数据结构实现
 */

#include "EnvironmentDataStructure.h"
#include <nlohmann/json.hpp>
#include <cstring>

using json = nlohmann::json;
using namespace std;

EnvironmentDataStructure::EnvironmentDataStructure() {
    // 初始化默认值（结构体构造函数已处理）
}

void EnvironmentDataStructure::clear() {
    m_indoorReturnAir.clear();
    m_outdoorAir.clear();
    m_supplyAir.clear();
    m_airQualityMetrics.clear();
}

bool EnvironmentDataStructure::isValid() const {
    return m_indoorReturnAir.isValid() &&
           m_outdoorAir.isValid() &&
           m_supplyAir.isValid() &&
           m_airQualityMetrics.isValid();
}

string EnvironmentDataStructure::toJson() const {
    json doc;

    // 室内回风数据
    doc["indoorReturnAir"]["temperature"] = m_indoorReturnAir.getTemperature();
    doc["indoorReturnAir"]["humidity"] = m_indoorReturnAir.getHumidity();
    doc["indoorReturnAir"]["pm25"] = m_indoorReturnAir.getPM25();
    doc["indoorReturnAir"]["co2"] = m_indoorReturnAir.getCO2();

    // 室外新风数据
    doc["outdoorAir"]["temperature"] = m_outdoorAir.getTemperature();
    doc["outdoorAir"]["humidity"] = m_outdoorAir.getHumidity();
    doc["outdoorAir"]["pm25"] = m_outdoorAir.getPM25();
    doc["outdoorAir"]["co2"] = m_outdoorAir.getCO2();

    // 送风数据
    doc["supplyAir"]["temperature"] = m_supplyAir.getTemperature();
    doc["supplyAir"]["humidity"] = m_supplyAir.getHumidity();
    doc["supplyAir"]["pm25"] = m_supplyAir.getPM25();
    doc["supplyAir"]["co2"] = m_supplyAir.getCO2();

    // 空气质量数据
    doc["airQuality"]["tvoc"] = m_airQualityMetrics.getTVOC();
    doc["airQuality"]["formaldehyde"] = m_airQualityMetrics.getFormaldehyde();

    return doc.dump();
}

bool EnvironmentDataStructure::fromJson(const string& jsonStr) {
    try {
        json doc = json::parse(jsonStr);

        // 解析室内回风数据
        if (doc.contains("indoorReturnAir")) {
            auto& ra = doc["indoorReturnAir"];
            if (ra.contains("temperature"))
                m_indoorReturnAir.ra1.temperature = ra["temperature"].get<float>();
            if (ra.contains("humidity"))
                m_indoorReturnAir.ra1.humidity = ra["humidity"].get<float>();
            if (ra.contains("pm25"))
                m_indoorReturnAir.ra1.pm25 = ra["pm25"].get<float>();
            if (ra.contains("co2"))
                m_indoorReturnAir.ra1.co2 = ra["co2"].get<float>();
        }

        // 解析室外新风数据
        if (doc.contains("outdoorAir")) {
            auto& oa = doc["outdoorAir"];
            if (oa.contains("temperature"))
                m_outdoorAir.oa.temperature = oa["temperature"].get<float>();
            if (oa.contains("humidity"))
                m_outdoorAir.oa.humidity = oa["humidity"].get<float>();
            if (oa.contains("pm25"))
                m_outdoorAir.oa.pm25 = oa["pm25"].get<float>();
            if (oa.contains("co2"))
                m_outdoorAir.oa.co2 = oa["co2"].get<float>();
        }

        // 解析送风数据
        if (doc.contains("supplyAir")) {
            auto& sa = doc["supplyAir"];
            if (sa.contains("temperature"))
                m_supplyAir.sa.temperature = sa["temperature"].get<float>();
            if (sa.contains("humidity"))
                m_supplyAir.sa.humidity = sa["humidity"].get<float>();
            if (sa.contains("pm25"))
                m_supplyAir.sa.pm25 = sa["pm25"].get<float>();
            if (sa.contains("co2"))
                m_supplyAir.sa.co2 = sa["co2"].get<float>();
        }

        // 解析空气质量数据
        if (doc.contains("airQuality")) {
            auto& aq = doc["airQuality"];
            if (aq.contains("tvoc"))
                m_airQualityMetrics.tvoc = aq["tvoc"].get<float>();
            if (aq.contains("formaldehyde"))
                m_airQualityMetrics.formaldehyde = aq["formaldehyde"].get<float>();
        }

        return true;
    } catch (const json::exception& e) {
        return false;
    }
}

void EnvironmentDataStructure::readFromModbusInputRegisters(const uint16_t* registers, size_t count) {
    // 根据协议文档v1.20，环境数据映射如下：
    // 寄存器地址（相对于输入寄存器起始地址0x2000）：
    // 0x000D (200DH): RA1温度 - 有符号整数，实际温度*10
    // 0x000E (200EH): RA1湿度 - 无符号整数，0-100%
    // 0x000F (200FH): RA1 PM2.5 - 无符号整数
    // 0x0010 (2010H): RA1 CO2 - 无符号整数
    // 0x0011 (2011H): OA温度 - 有符号整数，实际温度*10
    // 0x0012 (2012H): OA湿度 - 无符号整数，0-100%
    // 0x0013 (2013H): OA PM2.5 - 无符号整数
    // 0x0014 (2014H): OA CO2 - 无符号整数
    // 0x0015 (2015H): SA温度 - 有符号整数，实际温度*10
    // 0x0016 (2016H): SA湿度 - 无符号整数，0-100%
    // 0x0017 (2017H): SA PM2.5 - 无符号整数
    // 0x0018 (2018H): SA CO2 - 无符号整数
    // 0x0019 (2019H): TVOC - 无符号整数
    // 0x001A (201AH): 甲醛 - 无符号整数

    if (count < 0x001A - 0x000D + 1) {  // 至少需要14个寄存器
        return;  // 数据不足，返回
    }

    // 读取室内回风数据 (RA1) - 寄存器0x000D-0x0010
    int16_t ra1TempRaw = static_cast<int16_t>(registers[0x000D]);
    m_indoorReturnAir.ra1.temperature = convertTemperature(ra1TempRaw);
    m_indoorReturnAir.ra1.humidity = static_cast<float>(registers[0x000E]);
    m_indoorReturnAir.ra1.pm25 = static_cast<float>(registers[0x000F]);
    m_indoorReturnAir.ra1.co2 = static_cast<float>(registers[0x0010]);

    // 读取室外新风数据 (OA) - 寄存器0x0011-0x0014
    int16_t oaTempRaw = static_cast<int16_t>(registers[0x0011]);
    m_outdoorAir.oa.temperature = convertTemperature(oaTempRaw);
    m_outdoorAir.oa.humidity = static_cast<float>(registers[0x0012]);
    m_outdoorAir.oa.pm25 = static_cast<float>(registers[0x0013]);
    m_outdoorAir.oa.co2 = static_cast<float>(registers[0x0014]);

    // 读取送风数据 (SA) - 寄存器0x0015-0x0018
    int16_t saTempRaw = static_cast<int16_t>(registers[0x0015]);
    m_supplyAir.sa.temperature = convertTemperature(saTempRaw);
    m_supplyAir.sa.humidity = static_cast<float>(registers[0x0016]);
    m_supplyAir.sa.pm25 = static_cast<float>(registers[0x0017]);
    m_supplyAir.sa.co2 = static_cast<float>(registers[0x0018]);

    // 读取空气质量数据 - 寄存器0x0019-0x001A（v1.22：mg/m³，实际数值/100）
    m_airQualityMetrics.tvoc = static_cast<float>(registers[0x0019]) / 100.0f;
    m_airQualityMetrics.formaldehyde = static_cast<float>(registers[0x001A]) / 100.0f;
}

float EnvironmentDataStructure::convertTemperature(int16_t rawValue) {
    // 根据协议文档：温度寄存器值为有符号整数，实际温度 = rawValue / 10
    // 例如：rawValue = 253 表示 25.3°C
    return static_cast<float>(rawValue) / 10.0f;
}

int16_t EnvironmentDataStructure::encodeTemperature(float temperature) {
    // 将实际温度转换为Modbus寄存器值
    // 例如：25.3°C -> 253
    return static_cast<int16_t>(temperature * 10.0f);
}