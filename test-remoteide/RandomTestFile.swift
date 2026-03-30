import Foundation

struct RandomTestFile {
    let value: Int

    func doubled() -> Int {
        value * 2
    }
}

let sample = RandomTestFile(value: 21)
print("Random test value:", sample.doubled())
