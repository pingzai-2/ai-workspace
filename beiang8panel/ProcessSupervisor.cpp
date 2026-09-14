#include "ProcessSupervisor.h"
#include <cerrno>
#include <csignal>
#include <cstring>
#include <iostream>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t g_supervisorSignal = 0;

static void supervisorSignalHandler(int signal)
{
    g_supervisorSignal = signal;
}

static void installSupervisorSignalHandlers()
{
    struct sigaction action;
    std::memset(&action, 0, sizeof(action));
    action.sa_handler = supervisorSignalHandler;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;
    sigaction(SIGINT, &action, nullptr);
    sigaction(SIGTERM, &action, nullptr);
}

int runBackendProcesses(
    const std::vector<BackendProcessDefinition>& processes,
    BackendProcessEntry processEntry)
{
    if (processes.empty() || processEntry == nullptr) {
        return 1;
    }
    if (processes.size() == 1) {
        return processEntry(processes.front(), 1);
    }

    g_supervisorSignal = 0;
    installSupervisorSignalHandlers();

    std::vector<pid_t> children;
    children.reserve(processes.size());

    for (std::size_t index = 0; index < processes.size(); ++index) {
        const pid_t pid = fork();
        if (pid < 0) {
            std::cerr << "[Error] Failed to create " << processes[index].name
                      << ": " << strerror(errno) << std::endl;
            for (const pid_t child : children) {
                kill(child, SIGTERM);
            }
            for (const pid_t child : children) {
                waitpid(child, nullptr, 0);
            }
            return 1;
        }

        if (pid == 0) {
            signal(SIGINT, SIG_DFL);
            signal(SIGTERM, SIG_DFL);
            return processEntry(processes[index], processes.size());
        }

        children.push_back(pid);
        std::cout << "[Supervisor] Created " << processes[index].name
                  << ": pid=" << static_cast<long>(pid)
                  << ", scheduler="
                  << communicationSchedulerTypeName(processes[index].schedulerType)
                  << ", config=" << processes[index].configPath << std::endl;
    }

    int exitCode = 0;
    std::size_t runningCount = children.size();
    bool signalForwarded = false;

    while (runningCount > 0) {
        if (g_supervisorSignal != 0 && !signalForwarded) {
            for (const pid_t child : children) {
                if (child > 0) {
                    kill(child, g_supervisorSignal);
                }
            }
            signalForwarded = true;
        }

        int status = 0;
        const pid_t finished = waitpid(-1, &status, 0);
        if (finished < 0) {
            if (errno == EINTR) {
                continue;
            }
            std::cerr << "[Error] waitpid() failed: " << strerror(errno) << std::endl;
            return 1;
        }

        --runningCount;
        for (pid_t& child : children) {
            if (child == finished) {
                child = -1;
                break;
            }
        }

        if (WIFEXITED(status)) {
            const int childExitCode = WEXITSTATUS(status);
            if (childExitCode != 0) {
                exitCode = childExitCode;
            }
        } else if (WIFSIGNALED(status)) {
            exitCode = 128 + WTERMSIG(status);
        }
    }

    return exitCode;
}
