/**
 * 历史趋势页面API
 */

#ifndef HISTORYTRENDPAGE_H
#define HISTORYTRENDPAGE_H

#include <string>
#include "BasePage.h"

class HistoryTrendPage : public BasePage {
public:
    explicit HistoryTrendPage(DataManager* dataManager);

    // API: GET /api/history/trend — 趋势桶序列
    // range: day/week/month;dateParam: 可选 "YYYY-MM-DD" 锚点(空=今天)
    std::string getTrendData(const std::string& range, const std::string& dateParam);

    // API: GET /api/history/status — 采样与存储状态(诊断)
    std::string getStatusData();
};

#endif // HISTORYTRENDPAGE_H
