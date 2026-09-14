# BeiAng8Panel 代码规范

本文档定义了BeiAng8Panel项目的编码规范，确保代码质量和一致性。

## 目录

- [命名约定](#命名约定)
- [文件组织](#文件组织)
- [头文件规范](#头文件规范)
- [代码格式](#代码格式)
- [错误处理](#错误处理)
- [日志记录](#日志记录)
- [内存管理](#内存管理)
- [线程安全](#线程安全)
- [API响应规范](#api响应规范)

---

## 命名约定

### 类名

使用 **PascalCase**（大驼峰命名法）：

```cpp
class DataManager { };
class BasePage { };
class ApiResponse { };
```

### 成员变量

使用 **m_ 前缀** + camelCase：

```cpp
class DataManager {
private:
    std::string m_configPath;
    int m_httpPort;
    std::unique_ptr<BeiAng4CPGateway> m_gateway;
};
```

### 局部变量和参数

使用 **camelCase**（小驼峰命名法）：

```cpp
void processData(const std::string& input, int count) {
    std::string tempData = input;
    // ...
}
```

### 常量

使用 **UPPER_SNAKE_CASE**：

```cpp
constexpr int MAX_CONNECTIONS = 100;
constexpr int DEFAULT_TIMEOUT_MS = 5000;
```

### 函数/方法

使用 **camelCase**：

```cpp
class MyClass {
public:
    void loadData();
    std::string getConfigPath() const;
    bool initialize();
};
```

### 枚举

使用 **PascalCase**，枚举值使用 **PascalCase**：

```cpp
enum class WorkMode {
    Idle = 0,
    Manual = 1,
    Smart = 2
};

enum class LogLevel {
    DEBUG = 0,
    INFO = 1,
    WARNING = 2,
    ERROR = 3
};
```

### 命名空间

使用 **PascalCase**：

```cpp
namespace StringUtils { }
namespace TimeUtils { }
namespace ConvertUtils { }
```

---

## 文件组织

### 目录结构

```
BeiAng8Panel/
├── common/          # 通用工具和基础设施
├── structure/       # 数据结构定义
├── gateways/        # 设备通信网关
├── master/          # 核心业务模块
├── uiservice/       # HTTP API处理器
├── httpserver/      # HTTP服务器封装
├── config/          # 配置文件
└── docs/            # 文档
```

### 文件命名

- 头文件：`PascalCase.h`（如 `DataManager.h`）
- 源文件：`PascalCase.cpp`（如 `DataManager.cpp`）
- 每个类应有自己的头文件和源文件（通常）

---

## 头文件规范

### 头文件保护

使用 `#pragma once` 或传统包含保护：

```cpp
#ifndef DATAMANAGER_H
#define DATAMANAGER_H

// 内容...

#endif // DATAMANAGER_H
```

### 包含顺序

```cpp
// 1. 对应的头文件
#include "DataManager.h"

// 2. 项目头文件
#include "common/GlobalDefine.h"
#include "common/LogManager.h"

// 3. 第三方库头文件
#include <nlohmann/json.hpp>

// 4. 标准库头文件
#include <iostream>
#include <memory>
#include <string>
```

### 命名空间污染

**禁止在头文件中使用 `using namespace`**：

```cpp
// ❌ 错误 - 在头文件中
#ifndef MYCLASS_H
#define MYCLASS_H
#include <string>

using namespace std;  // 禁止！

class MyClass {
    string m_name;  // 避免
};
#endif

// ✅ 正确 - 在头文件中
#ifndef MYCLASS_H
#define MYCLASS_H
#include <string>

class MyClass {
    std::string m_name;  // 使用完整的命名空间
};
#endif

// ✅ 正确 - 在.cpp文件中可以使用
#include "MyClass.h"

using namespace std;  // 在源文件中允许
```

### 前向声明

尽可能使用前向声明减少包含依赖：

```cpp
// 头文件中使用前向声明
class DataManager;
class DataAcquisitionModule;

// 源文件中包含完整定义
#include "DataManager.h"
```

---

## 代码格式

### 缩进

使用 **4个空格**缩进，不使用制表符（Tab）：

```cpp
class MyClass {
public:
    void myFunction() {
        if (condition) {
            doSomething();
        }
    }
};
```

### 大括号

使用 **Allman风格**（大括号另起一行）：

```cpp
if (condition)
{
    doSomething();
}
else
{
    doSomethingElse();
}
```

对于短函数可以使用单行：

```cpp
int getValue() { return m_value; }
```

### 行长度

建议最大行长度为 **120个字符**。

---

## 错误处理

### 返回值

对于可能失败的操作，返回 `bool` 或错误码：

```cpp
bool initialize();
int processData(); // 返回处理的数据量，负数表示错误
```

### 异常

仅在异常情况下使用异常：

```cpp
try {
    // 可能抛出异常的操作
} catch (const std::exception& e) {
    LOG_ERROR("Exception: {}", e.what());
    return false;
}
```

### 错误传播

使用统一的错误响应（通过 `ApiResponse`）：

```cpp
std::string MyPage::getData() {
    if (!dataManager()) {
        return buildError("DataManager not available");
    }
    // ...
}
```

---

## 日志记录

### 日志级别

| 级别 | 用途 |
|------|------|
| DEBUG | 调试信息，仅开发时使用 |
| INFO | 一般信息，程序正常运行状态 |
| WARNING | 警告，不影响程序运行但需注意 |
| ERROR | 错误，操作失败但不影响程序继续 |
| FATAL | 致命错误，程序无法继续运行 |

### 日志格式

```cpp
LOG_DEBUG("Detailed debug info: value={}", value);
LOG_INFO("Service started on port {}", port);
LOG_WARN("Configuration file not found, using defaults");
LOG_ERROR("Failed to connect to device: {}", error);
LOG_CRITICAL("Critical system failure");
```

### 日志最佳实践

1. **关键操作必须记录**：初始化、启动、停止
2. **错误必须记录上下文**：包含足够的诊断信息
3. **避免过度日志**：不要在循环中频繁记录DEBUG日志
4. **使用结构化日志**：使用 `{}` 占位符而非字符串拼接

```cpp
// ✅ 正确
LOG_INFO("User {} logged in from {}", username, ip);

// ❌ 避免
LOG_INFO("User " + username + " logged in from " + ip);
```

---

## 内存管理

### 智能指针

优先使用智能指针管理动态内存：

```cpp
// 独占所有权
std::unique_ptr<DataManager> m_dataManager;

// 共享所有权
std::shared_ptr<Config> m_config;

// 弱引用，避免循环依赖
std::weak_ptr<Resource> m_resource;
```

### 禁止的操作

```cpp
// ❌ 禁止裸指针管理动态内存
DataManager* manager = new DataManager(); // 不要这样做
delete manager;  // 容易忘记或异常时未执行

// ✅ 正确
auto manager = std::make_unique<DataManager>();
```

---

## 线程安全

### 互斥锁

使用 `std::mutex` 保护共享数据：

```cpp
class DataManager {
private:
    std::mutex m_dataMutex;
    SomeData m_data;

public:
    void updateData(const SomeData& newData) {
        std::lock_guard<std::mutex> lock(m_dataMutex);
        m_data = newData;
    }
};
```

### RAII锁

优先使用RAII锁管理：

```cpp
// ✅ 正确 - 自动释放
{
    std::lock_guard<std::mutex> lock(m_mutex);
    // 临界区
} // 自动解锁

// ❌ 避免 - 手动管理容易出错
m_mutex.lock();
// 临界区
m_mutex.unlock();  // 如果异常可能不会执行
```

### 数据访问模式

提供显式的锁定/解锁接口：

```cpp
class DataManager {
public:
    void lockData();
    void unlockData();

    // 使用示例
    dataManager.lockData();
    // 访问数据...
    dataManager.unlockData();
};
```

---

## API响应规范

### 统一响应格式

所有API接口应返回统一格式的JSON响应：

```json
{
    "code": 0,
    "message": "Success",
    "data": { ... }
}
```

### 使用ApiResponse类

```cpp
// 成功响应
return ApiResponse::success(dataJson);
return ApiResponse::success(); // 默认空数据

// 错误响应
return ApiResponse::error(1001, "Invalid parameter");
return ApiResponse::deviceOffline();
return ApiResponse::timeout();

// 未实现功能
return ApiResponse::notImplemented("featureName");
```

### 错误码定义

| 错误码 | 常量名 | 描述 |
|--------|--------|------|
| 0 | CODE_SUCCESS | 成功 |
| 1001 | CODE_INVALID_PARAM | 参数错误 |
| 1002 | CODE_DEVICE_OFFLINE | 设备离线 |
| 1003 | CODE_OPERATION_FAILED | 操作失败 |
| 1004 | CODE_TIMEOUT | 操作超时 |
| 1005 | CODE_INTERNAL_ERROR | 内部错误 |
| 1006 | CODE_NOT_IMPLEMENTED | 功能未实现 |

---

## 注释规范

### 文件头注释

```cpp
/**
 * DataManager - 数据管理器类
 *
 * 负责管理整个系统的数据，包括：
 * 1. 配置数据
 * 2. 设备状态数据
 * 3. 历史数据
 * 4. UI状态数据
 */
```

### 类注释

```cpp
/**
 * @brief 统一的API响应构建器
 *
 * 提供标准化的API响应格式，消除代码中返回空"{}"的问题
 */
class ApiResponse { };
```

### 函数注释

```cpp
/**
 * @brief 从JSON文件加载配置
 * @param path 配置文件路径
 * @return true 加载成功
 * @return false 加载失败
 */
bool load(const std::string& path);
```

### 行内注释

```cpp
// 单行注释：简要说明

/*
 * 多行注释：
 * 详细说明复杂的逻辑
 */
```

---

## 最佳实践

1. **保持简洁**：函数应该短小精悍，专注单一职责
2. **避免重复**：提取公共逻辑到可重用的函数或类
3. **明确意图**：使用有意义的变量名和函数名
4. **及时重构**：发现代码异味时立即重构
5. **编写测试**：为新功能编写单元测试

---

## 检查清单

提交代码前检查：

- [ ] 头文件中没有 `using namespace`
- [ ] 成员变量使用 `m_` 前缀
- [ ] 使用智能指针管理内存
- [ ] 错误处理使用 `ApiResponse`
- [ ] 关键操作有日志记录
- [ ] 共享数据访问有锁保护
- [ ] 代码符合命名约定
- [ ] 注释清晰准确
