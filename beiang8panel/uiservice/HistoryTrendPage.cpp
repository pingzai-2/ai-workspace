/**
 * 历史趋势页面API实现
 */

#include "HistoryTrendPage.h"
#include "history/HistoryRecorder.h"

HistoryTrendPage::HistoryTrendPage(DataManager* dataManager)
    : BasePage(dataManager)
{
}

std::string HistoryTrendPage::getTrendData(const std::string& range, const std::string& dateParam)
{
    HistoryRecorder* recorder = dataManager()->getHistoryRecorder();
    if (!recorder) {
        return buildError("历史趋势采样器未初始化");
    }
    return buildSuccessWithData(recorder->getTrendData(range, dateParam));
}

std::string HistoryTrendPage::getStatusData()
{
    HistoryRecorder* recorder = dataManager()->getHistoryRecorder();
    if (!recorder) {
        return buildError("历史趋势采样器未初始化");
    }
    return buildSuccessWithData(recorder->getStatusData());
}
