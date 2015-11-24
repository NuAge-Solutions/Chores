import Foundation

public typealias ChoreResult = (result: Int32, stdout: String, stderr: String)

private func string_trim(string: NSString!) -> String {
    return string.stringByTrimmingCharactersInSet(.whitespaceAndNewlineCharacterSet()) ?? ""
}

internal func chore_task(command: String, _ arguments: [String] = [String](), stdin: String = "", dir: String? = nil) -> ChoreResult {
    let task = NSTask()
    
    task.launchPath = command
    task.arguments = arguments
    
    if let d = dir {
        task.currentDirectoryPath = d
    }
    
    if !(command as NSString).absolutePath {
        task.launchPath = (chore_task("/bin/bash", ["-l", "-c", "which " + command])).stdout
    }
    
    if let lp = task.launchPath {
        if !NSFileManager.defaultManager().fileExistsAtPath(lp) {
            return (255, "", "\(lp): launch path not accessible")
        }
    }
    
    if stdin.characters.count > 0 {
        let stdinPipe = NSPipe()
        task.standardInput = stdinPipe
        
        let stdinHandle = stdinPipe.fileHandleForWriting
        
        if let data = stdin.dataUsingEncoding(NSUTF8StringEncoding) {
            stdinHandle.writeData(data)
            stdinHandle.closeFile()
        }
    }
    
    let stderrPipe = NSPipe()
    task.standardError = stderrPipe
    
    let stderrHandle = stderrPipe.fileHandleForReading
    
    let stdoutPipe = NSPipe()
    task.standardOutput = stdoutPipe
    
    let stdoutHandle = stdoutPipe.fileHandleForReading
    
    task.launch()
    task.waitUntilExit()
    
    let stderr = string_trim(NSString(data: stderrHandle.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)) ?? ""
    let stdout = string_trim(NSString(data: stdoutHandle.readDataToEndOfFile(), encoding: NSUTF8StringEncoding)) ?? ""
    
    return (task.terminationStatus, stdout, stderr)
}

prefix operator > {}

public prefix func > (command: String) -> ChoreResult {
    return chore_task(command)
}

public prefix func > (command: [String]) -> ChoreResult {
    switch command.count {
    case 0:
        return (0, "", "")
    case 1:
        return chore_task(command[0])
    default:
        break
    }
    
    return chore_task(command[0], Array(command[1..<command.count]))
}

public prefix func > (command: (String, String)) -> ChoreResult {
    return chore_task(command.1, dir: command.0)
}

public prefix func > (command: (String, [String])) -> ChoreResult {
    switch command.1.count {
    case 0:
        return (0, "", "")
    case 1:
        return chore_task(command.1[0], dir: command.0)
    default:
        break
    }
    
    return chore_task(command.1[0], Array(command.1[1..<command.1.count]), dir: command.0)
}

infix operator | {}

public func | (left: ChoreResult, right: String) -> ChoreResult {
    return left|[right]
}

public func | (left: ChoreResult, right: [String]) -> ChoreResult {
    if left.result != 0 {
        return left
    }
    
    let arguments = right.count >= 2 ? Array(right[1..<right.count]) : [String]()
    return chore_task(right[0], arguments, stdin: left.stdout)
}

public func | (left: ChoreResult, right: ((String) -> String)) -> ChoreResult {
    if left.result != 0 {
        return left
    }
    
    return (0, right(left.stdout), "")
}

public func | (left: (() -> String), right: String) -> ChoreResult {
    return (0, left(), "")|right
}

public func | (left: (() -> String), right: [String]) -> ChoreResult {
    return (0, left(), "")|right
}

public func | (left: String, right: String) -> ChoreResult {
    return (0, left, "")|right
}

public func | (left: String, right: [String]) -> ChoreResult {
    return (0, left, "")|right
}
