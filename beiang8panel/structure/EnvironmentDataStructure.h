/**
 * 环境数据结构类
 *
 * 定义用于存储环境参数的数据结构（根据协议文档v1.20）
 * 包含回风(RA)、新风(OA)、送风(SA)数据以及TVOC和甲醛数据
 * 对应Modbus输入寄存器地址200DH~201AH
 */

#ifndef ENVIRONMENTDATASTRUCTURE_H
#define ENVIRONMENTDATASTRUCTURE_H

#include <string>
#include <cstdint>

// ========== 环境传感器基础数据结构 ==========
struct EnvironmentSensorData {
    float temperature;    // 温度（单位：℃，寄存器原始值为实际温度*10的有符号整数）
    float humidity;       // 湿度（单位：%RH，范围0-100，整数）
    float pm25;          // PM2.5浓度（单位：μg/m³）
    float co2;           // CO2浓度（单位：ppm）

    EnvironmentSensorData()
        : temperature(0.0f)
        , humidity(0.0f)
        , pm25(0.0f)
        , co2(0.0f)
    {
    }

    // 清零数据
    void clear() {
        temperature = 0.0f;
        humidity = 0.0f;
        pm25 = 0.0f;
        co2 = 0.0f;
    }

    // 数据有效性检查
    bool isValid() const {
        return (humidity >= 0.0f && humidity <= 100.0f);
    }
};

// ========== 室内回风数据 (Return Air - RA) ==========
struct IndoorReturnAirData {
    EnvironmentSensorData ra1;  // RA1传感器数据（室内回风，寄存器200DH-2010H）

    IndoorReturnAirData() = default;

    // 获取室内回风温度
    float getTemperature() const { return ra1.temperature; }

    // 获取室内回风湿度
    float getHumidity() const { return ra1.humidity; }

    // 获取室内PM2.5
    float getPM25() const { return ra1.pm25; }

    // 获取室内CO2
    float getCO2() const { return ra1.co2; }

    // 数据有效性检查
    bool isValid() const {
        return ra1.isValid();
    }

    // 清零数据
    void clear() {
        ra1.clear();
    }
};

// ========== 室外新风数据 (Outdoor Air - OA) ==========
struct OutdoorAirData {
    EnvironmentSensorData oa;   // OA传感器数据（室外新风，寄存器2011H-2014H）

    OutdoorAirData() = default;

    // 获取室外温度
    float getTemperature() const { return oa.temperature; }

    // 获取室外湿度
    float getHumidity() const { return oa.humidity; }

    // 获取室外PM2.5
    float getPM25() const { return oa.pm25; }

    // 获取室外CO2
    float getCO2() const { return oa.co2; }

    // 数据有效性检查
    bool isValid() const {
        return oa.isValid();
    }

    // 清零数据
    void clear() {
        oa.clear();
    }
};

// ========== 送风数据 (Supply Air - SA) ==========
struct SupplyAirData {
    EnvironmentSensorData sa;   // SA传感器数据（送风，寄存器2015H-2018H）

    SupplyAirData() = default;

    // 获取送风温度
    float getTemperature() const { return sa.temperature; }

    // 获取送风湿度
    float getHumidity() const { return sa.humidity; }

    // 获取送风PM2.5
    float getPM25() const { return sa.pm25; }

    // 获取送风CO2
    float getCO2() const { return sa.co2; }

    // 数据有效性检查
    bool isValid() const {
        return sa.isValid();
    }

    // 清零数据
    void clear() {
        sa.clear();
    }
};

// ========== 空气质量数据 (TVOC & 甲醛) ==========
struct AirQualityMetrics {
    float tvoc;           // TVOC总挥发性有机化合物（单位：mg/m³或ppb，寄存器2019H）
    float formaldehyde;   // 甲醛浓度（单位：mg/m³，寄存器201AH）

    AirQualityMetrics()
        : tvoc(0.0f)
        , formaldehyde(0.0f)
    {
    }

    // 获取TVOC浓度
    float getTVOC() const { return tvoc; }

    // 获取甲醛浓度
    float getFormaldehyde() const { return formaldehyde; }

    // 数据有效性检查
    bool isValid() const {
        return (tvoc >= 0.0f && formaldehyde >= 0.0f);
    }

    // 清零数据
    void clear() {
        tvoc = 0.0f;
        formaldehyde = 0.0f;
    }
};

// ========== 环境数据结构主类 ==========
class EnvironmentDataStructure {
public:
    EnvironmentDataStructure();
    ~EnvironmentDataStructure() = default;

    // ========== 数据访问接口 ==========

    // 室内回风数据访问
    IndoorReturnAirData& getIndoorReturnAir() { return m_indoorReturnAir; }
    const IndoorReturnAirData& getIndoorReturnAir() const { return m_indoorReturnAir; }

    // 室外新风数据访问
    OutdoorAirData& getOutdoorAir() { return m_outdoorAir; }
    const OutdoorAirData& getOutdoorAir() const { return m_outdoorAir; }

    // 送风数据访问
    SupplyAirData& getSupplyAir() { return m_supplyAir; }
    const SupplyAirData& getSupplyAir() const { return m_supplyAir; }

    // 空气质量数据访问
    AirQualityMetrics& getAirQualityMetrics() { return m_airQualityMetrics; }
    const AirQualityMetrics& getAirQualityMetrics() const { return m_airQualityMetrics; }

    // ========== 便捷访问方法 ==========

    // 室内环境参数快捷访问
    float getIndoorTemperature() const { return m_indoorReturnAir.getTemperature(); }
    float getIndoorHumidity() const { return m_indoorReturnAir.getHumidity(); }
    float getIndoorPM25() const { return m_indoorReturnAir.getPM25(); }
    float getIndoorCO2() const { return m_indoorReturnAir.getCO2(); }

    // 室外环境参数快捷访问
    float getOutdoorTemperature() const { return m_outdoorAir.getTemperature(); }
    float getOutdoorHumidity() const { return m_outdoorAir.getHumidity(); }
    float getOutdoorPM25() const { return m_outdoorAir.getPM25(); }
    float getOutdoorCO2() const { return m_outdoorAir.getCO2(); }

    // 送风环境参数快捷访问
    float getSupplyTemperature() const { return m_supplyAir.getTemperature(); }
    float getSupplyHumidity() const { return m_supplyAir.getHumidity(); }
    float getSupplyPM25() const { return m_supplyAir.getPM25(); }
    float getSupplyCO2() const { return m_supplyAir.getCO2(); }

    // 空气质量参数快捷访问
    float getTVOC() const { return m_airQualityMetrics.getTVOC(); }
    float getFormaldehyde() const { return m_airQualityMetrics.getFormaldehyde(); }

    // ========== 数据处理方法 ==========

    // 清零所有环境数据
    void clear();

    // 检查所有数据是否有效
    bool isValid() const;

    // 数据序列化/反序列化
    std::string toJson() const;
    bool fromJson(const std::string& json);

    // Modbus寄存器映射（从输入寄存器读取环境数据）
    void readFromModbusInputRegisters(const uint16_t* registers, size_t count);

    // ========== 辅助转换方法 ==========

    // 温度转换：从Modbus原始值转换为实际温度
    static float convertTemperature(int16_t rawValue);

    // 温度转换：从实际温度转换为Modbus原始值
    static int16_t encodeTemperature(float temperature);

private:
    IndoorReturnAirData m_indoorReturnAir;    // 室内回风数据
    OutdoorAirData m_outdoorAir;             // 室外新风数据
    SupplyAirData m_supplyAir;               // 送风数据
    AirQualityMetrics m_airQualityMetrics;   // 空气质量数据
};

#endif // ENVIRONMENTDATASTRUCTURE_H