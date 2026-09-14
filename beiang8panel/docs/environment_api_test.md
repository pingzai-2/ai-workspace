# 环境数据API测试文档

## 新增API接口

### GET /api/idle/environment

获取室内/室外环境数据，包括RA（回风）、OA（新风）、SA（送风）的温度、湿度、PM2.5、CO2，以及TVOC和甲醛浓度。

## API详细信息

### 请求格式

```
GET /api/idle/environment
```

### 响应格式

```json
{
  "code": 200,
  "message": "Success",
  "data": {
    "indoorReturnAir": {
      "temperature": 25.3,
      "humidity": 65.0,
      "pm25": 35.0,
      "co2": 450.0
    },
    "outdoorAir": {
      "temperature": 28.5,
      "humidity": 70.0,
      "pm25": 42.0,
      "co2": 380.0
    },
    "supplyAir": {
      "temperature": 24.8,
      "humidity": 62.0,
      "pm25": 28.0,
      "co2": 420.0
    },
    "airQuality": {
      "tvoc": 0.15,
      "formaldehyde": 0.025
    }
  }
}
```

### 数据字段说明

#### indoorReturnAir (室内回风数据)
- `temperature`: 室内回风温度（℃），精度0.1℃
- `humidity`: 室内回风湿度（%RH），范围0-100
- `pm25`: 室内PM2.5浓度（μg/m³）
- `co2`: 室内CO2浓度（ppm）

#### outdoorAir (室外新风数据)
- `temperature`: 室外新风温度（℃），精度0.1℃
- `humidity`: 室外新风湿度（%RH），范围0-100
- `pm25`: 室外PM2.5浓度（μg/m³）
- `co2`: 室外CO2浓度（ppm）

#### supplyAir (送风数据)
- `temperature`: 送风温度（℃），精度0.1℃
- `humidity`: 送风湿度（%RH），范围0-100
- `pm25`: 送风PM2.5浓度（μg/m³）
- `co2`: 送风CO2浓度（ppm）

#### airQuality (空气质量数据)
- `tvoc`: TVOC总挥发性有机化合物浓度（mg/m³）
- `formaldehyde`: 甲醛浓度（mg/m³）

## Modbus寄存器映射

根据当前 v1.21 协议，环境数据对应以下 Modbus 输入寄存器地址：

### RA1传感器数据（200DH-2010H）
- 200DH: RA1温度（实际温度*10）
- 200EH: RA1湿度（0-100）
- 200FH: RA1 PM2.5
- 2010H: RA1 CO2

### OA传感器数据（2011H-2014H）
- 2011H: OA温度（实际温度*10）
- 2012H: OA湿度（0-100）
- 2013H: OA PM2.5
- 2014H: OA CO2

### SA传感器数据（2015H-2018H）
- 2015H: SA温度（实际温度*10）
- 2016H: SA湿度（0-100）
- 2017H: SA PM2.5
- 2018H: SA CO2

### 空气质量数据（2019H-201AH）
- 2019H: TVOC
- 201AH: 甲醛

## 测试方法

### 使用curl测试

```bash
# 启动服务后测试
curl -X GET http://localhost:8080/api/idle/environment

# 或者使用jq格式化输出
curl -X GET http://localhost:8080/api/idle/environment | jq
```

### 使用浏览器测试

直接在浏览器中访问：
```
http://localhost:8080/api/idle/environment
```

### 使用Postman测试

1. 创建新的GET请求
2. URL: `http://localhost:8080/api/idle/environment`
3. 发送请求并查看响应

## 错误响应

### 设备离线
```json
{
  "code": 500,
  "message": "Gateway not available"
}
```

### 读取失败
```json
{
  "code": 500,
  "message": "Failed to read environment data: [具体错误信息]"
}
```

### 数据无效
如果Modbus通信失败，系统会返回缓存的环境数据（如果有），但会在日志中记录警告信息。

## 集成到待机页面

在Flutter前端中，可以通过以下方式调用此API：

```dart
// 获取环境数据
final response = await http.get(
  Uri.parse('http://localhost:8080/api/idle/environment'),
);

if (response.statusCode == 200) {
  final data = json.decode(response.body);
  
  // 解析室内回风数据
  final indoorData = data['data']['indoorReturnAir'];
  print('室内温度: ${indoorData['temperature']}℃');
  print('室内湿度: ${indoorData['humidity']}%');
  
  // 解析室外新风数据
  final outdoorData = data['data']['outdoorAir'];
  print('室外温度: ${outdoorData['temperature']}℃');
  print('室外湿度: ${outdoorData['humidity']}%');
  
  // 解析空气质量数据
  final airQuality = data['data']['airQuality'];
  print('TVOC: ${airQuality['tvoc']} mg/m³');
  print('甲醛: ${airQuality['formaldehyde']} mg/m³');
}
```

## 注意事项

1. **数据刷新频率**: 建议前端不要频繁轮询此接口，推荐30-60秒刷新一次
2. **设备状态**: 如果设备处于离线状态，此接口会返回错误或缓存数据
3. **数据精度**: 温度数据精度为0.1℃，其他数据为整数
4. **单位一致性**: 确保前端显示时使用正确的单位

## 日志调试

启用调试日志后，可以在服务端看到详细的环境数据读取日志：

```
[BeiAng4CPGateway] Read environment data successfully: 
RA1: 25.3°C, 65.0%, 35μg/m³, 450ppm | 
OA: 28.5°C, 70.0%, 42μg/m³, 380ppm | 
SA: 24.8°C, 62.0%, 28μg/m³, 420ppm | 
TVOC: 0.15, HCHO: 0.025

[IdlePage] Environment data: 
RA=25.3°C/65.0%, OA=28.5°C/70.0%, SA=24.8°C/62.0%, 
TVOC=0.15, HCHO=0.025
```

## 实现细节

- **数据结构**: EnvironmentDataStructure
- **Modbus读取**: BeiAng4CPGateway::readEnvironmentData()
- **API处理**: IdlePage::getEnvironmentData()
- **HTTP路由**: HttpServerBasedOnLibhv::handleGetEnvironmentData()
- **寄存器范围**: 200DH-201AH（共30个寄存器）
- **读取方式**: Modbus功能码04H（读输入寄存器）

## 编译和部署

确保在CMake配置时启用了HTTP服务器：

```bash
mkdir -p build && cd build
cmake -DENABLE_HTTP_SERVER=ON ..
make -j$(nproc)
```

编译成功后，可执行文件位于：`out/BeiAng8Panel`

## 相关文件

- `structure/EnvironmentDataStructure.h` - 环境数据结构定义
- `gateways/BeiAng4CPGateway.cpp` - Modbus通信实现
- `uiservice/IdlePage.cpp` - API处理器实现
- `httpserver/HttpServerBasedOnLibhv.cpp` - HTTP路由注册
