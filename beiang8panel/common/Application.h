/**
 * Application - 应用程序主类
 *
 * 封装所有核心模块的生命周期管理，替代全局静态指针
 * 负责：DataManager, DataAcquisitionModule, ScheduleController, HttpServer
 */

#ifndef APPLICATION_H
#define APPLICATION_H

#include "gateways/CommunicationSchedulerType.h"
#include <memory>
#include <atomic>
#include <string>

#ifdef ENABLE_HTTP_SERVER
#include "httpserver/HttpServerBasedOnLibhv.h"
#endif

// 前向声明
class DataManager;
class DataAcquisitionModule;
class ScheduleController;
class LocalDeviceModule;
class WifiManager;
class OtaManager;
class CommunicationChannel;
enum class ApplicationRole {
    Full,
    FourCpCommunication,
    CommunicationOnly
};
class ModbusCommandModule;

/**
 * @brief 应用程序主类
 *
 * 管理整个应用程序的生命周期：
 * 1. 初始化所有模块
 * 2. 启动服务
 * 3. 处理关闭
 * 4. 优雅退出
 */
class Application {
public:
    /**
     * @brief 构造函数
     * @param configPath 配置文件路径
     */
    Application(const std::string& configPath,
        CommunicationSchedulerType communicationSchedulerType,
        ApplicationRole role = ApplicationRole::Full);

    /**
     * @brief 析构函数 - 自动调用shutdown()
     */
    ~Application();

    /**
     * @brief 初始化所有模块
     * @return true 初始化成功
     * @return false 初始化失败
     */
    bool initialize();

    // ========== RS485通讯开关 (全停语义: 轮询+命令+定时任务) ==========
    // 返回false表示底层模块启停失败
    bool setRs485Enabled(bool enable);
    bool isRs485Enabled() const { return m_rs485Enabled.load(); }

    /**
     * @brief 关闭所有模块
     */
    void shutdown();

    /**
     * @brief 运行应用程序主循环
     * @return int 退出码（0表示正常退出）
     */
    int run();

    /**
     * @brief 请求停止应用程序
     */
    void requestStop();

    /**
     * @brief 获取数据管理器
     * @return DataManager* 数据管理器指针
     */
    DataManager* getDataManager() const { return m_dataManager.get(); }

    /**
     * @brief 获取配置文件路径
     * @return std::string 配置文件路径
     */
    std::string getConfigPath() const { return m_configPath; }

private:
    /**
     * @brief 打印欢迎信息
     */
    void printWelcome();

    /**
     * @brief 注册信号处理器
     */
    void setupSignalHandlers();

    /**
     * @brief 信号处理函数
     * @param signal 信号编号
     */
    static void signalHandler(int signal);

    /**
     * @brief 设置全局应用实例指针（用于信号处理）
     */
    void setGlobalInstance();

    // 配置
    std::string m_configPath;
    CommunicationSchedulerType m_communicationSchedulerType;
    ApplicationRole m_role;

    // 核心模块
    std::unique_ptr<DataManager> m_dataManager;
    std::unique_ptr<DataAcquisitionModule> m_dataAcquisition;
    std::unique_ptr<ModbusCommandModule> m_modbusCommandModule;
    std::unique_ptr<CommunicationChannel> m_communicationChannel;
    std::unique_ptr<LocalDeviceModule> m_localDeviceModule;
    std::unique_ptr<WifiManager> m_wifiManager;
    std::unique_ptr<OtaManager> m_otaManager;
    std::unique_ptr<ScheduleController> m_scheduleController;
    std::atomic<bool> m_rs485Enabled{true}; // RS485开关状态(持久化到UDISK)

    bool loadRs485Enabled() const;
    void saveRs485Enabled(bool enable) const;

#ifdef ENABLE_HTTP_SERVER
    std::unique_ptr<HttpServerBasedOnLibhv> m_httpServer;
#endif

    // 状态
    bool m_initialized;
    bool m_shouldStop;

    // 全局实例指针（用于信号处理）
    static Application* s_globalInstance;
};

#endif // APPLICATION_H
