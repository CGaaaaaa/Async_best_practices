# MoonBit Async Best Practices Examples

This repository systematically demonstrates efficient usage and best practices of `moonbitlang/async` through runnable, testable examples.

## 📖 Introduction

`moonbitlang/async` is MoonBit's asynchronous programming library, providing core features such as structured concurrency, task group management, timeout control, retry strategies, queues, and semaphores. This repository helps programmers and AI code assistants quickly master asynchronous programming best practices through **25 carefully designed examples**.

### Why This Library?

- **Steep Learning Curve**: Asynchronous programming involves complex concepts like task groups, cancellation propagation, and structured concurrency
- **Scattered Best Practices**: Official documentation may lack complete examples for real-world business scenarios
- **AI-Assisted Development**: Through systematic examples, AI code assistants can better understand and use the Async library
- **Quick Start**: Every example is runnable, and with tests you can intuitively see the execution results

## 🎯 Project Highlights

- 🎉 **100% API Coverage** (28/28 APIs, complete coverage!)
- ✅ **25 Complete Examples** (8 beginner + 17 advanced, including 1 business integration example)
- ✅ **100% Test Pass Rate** (all examples have snapshot tests)
- ✅ **~1600 lines of carefully designed code**
- 📚 **Systematic Documentation**: From basic concepts to advanced patterns, step by step
- 🔍 **Runnable Examples**: Every example can be directly run and tested

## 📁 Project Structure

```
Async_best_practices/
├── README.mbt.md              # Main project documentation (this file)
├── docs/
│   └── best_practices.mbt.md  # Detailed best practices guide
├── src/
│   ├── Async_best_practices.mbt      # 25 example implementations
│   └── Async_best_practices_test.mbt # Corresponding test cases
├── moon.mod.json              # Module configuration
└── LICENSE                    # Apache-2.0 License
```

### Documentation Overview

- **README.mbt.md** (this file): Project overview, quick start, example index
- **docs/best_practices.mbt.md**: Systematic best practices guide with design philosophy and detailed explanations
- **src/Async_best_practices.mbt**: Implementation code for all examples, each function has detailed comments
- **src/Async_best_practices_test.mbt**: Test cases using `inspect()` snapshot testing

### Runtime Environment

- Recommended to use **native target** (`--target native`)
- Tests use `inspect(...)` snapshots for easy learning and regression

## 🚀 Quick Start

### Requirements

- **MoonBit Toolchain**: MoonBit installed (refer to official documentation [https://docs.moonbitlang.com](https://docs.moonbitlang.com))
- **Native Target**: Recommended to use `--target native`
  - macOS: Install Xcode Command Line Tools to ensure C toolchain is available
  - Linux: Ensure gcc/clang and other C compilers are installed
  - Windows: Configure C toolchain

### Installation Steps

#### 1. Clone or Download This Repository

```bash
git clone https://github.com/CGaaaaaa/Async_best_practices.git
cd Async_best_practices
```

#### 2. Configure Dependencies

Ensure dependencies are included in module `moon.mod.json`:

```json
{
  "deps": {
    "moonbitlang/async": "0.11.0"
  }
}
```

#### 3. Configure Package Imports

Import required sub-packages in package `moon.pkg.json`:

```json
{
  "import": [
    "moonbitlang/async",
    "moonbitlang/async/semaphore",
    "moonbitlang/async/aqueue"
  ]
}
```

#### 4. Run Tests

```bash
# Run all tests
moon test --target native

# Run and update snapshots (if behavior changes)
moon test --target native --update
```

#### 5. View Example Code

Open `src/Async_best_practices.mbt` directly and search for function names. Each function has detailed documentation comments and examples.

### Using in Your Project

If you want to reference these examples in your own project:

1. **Copy Example Code**: Copy needed functions from `src/Async_best_practices.mbt`
2. **Read Documentation Comments**: Each function has detailed comments starting with `///|`, explaining usage and best practices
3. **Run Tests for Verification**: Reference test cases in `src/Async_best_practices_test.mbt`
4. **Read Best Practices Guide**: Check `docs/best_practices.mbt.md` to understand design philosophy

## 📚 Example Index

This repository contains **25 complete examples**, covering various asynchronous programming patterns from beginner to advanced. All examples are in `src/Async_best_practices.mbt`, and each function has detailed documentation comments.

### Beginner Examples (Examples 1-8)

Suitable for developers just starting to learn the Async library, covering the most commonly used basic features:

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 1 | `hello_async` | Simple async function with timeout | `with_timeout_opt` |
| 2 | `concurrent_tasks` | Concurrent execution of multiple tasks | `with_task_group`, `spawn`, `wait` |
| 3 | `timeout_example` | Timeout handling for long-running tasks | Timeout control |
| 4 | `sequential_pipeline` | Sequential async operations (data processing pipeline) | Async pipeline |
| 5 | `race_example` | Race mode - return fastest completed task | `spawn_bg`, `return_immediately` |
| 6 | `retry_example` | Retry mechanism - manual exponential backoff | Manual retry logic |
| 7 | `error_handling_example` | Error isolation - allow partial task failures | `allow_failure=true` |
| 8 | `batch_processing` | Batch processing - concurrent processing of collection elements | Batch concurrency |

### Advanced Examples (Examples 9-25)

Suitable for developers with some foundation, covering more complex asynchronous programming patterns and best practices:

#### Structured Concurrency and Task Management

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 9 | `demo_spawn` | Structured concurrency - task group management | `with_task_group`, `spawn_bg` |
| 19 | `demo_task_wait_and_try_wait` | Task handle and waiting | `Task::try_wait()`, `Task::wait()` |
| 21 | `demo_group_defer` | Group-level cleanup | `add_defer`, FILO order |

#### Timeout and Cancellation Control

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 10 | `demo_with_timeout` | Timeout and cancellation propagation | `with_timeout`, cancellation propagation |
| 14 | `demo_with_timeout_opt` | Optional timeout | `with_timeout_opt`, `Option` handling |
| 12 | `demo_protect_from_cancel` | Critical section cancellation protection | `protect_from_cancel` |

#### Retry Strategies

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 13 | `demo_retry_fixed` | Fixed delay retry | `retry(FixedDelay(...))` |
| 16 | `demo_retry_exponential` | Exponential backoff retry | `retry(ExponentialDelay(...))` |
| 22 | `demo_retry_immediate` | Immediate retry | `retry(Immediate)` |
| 23 | `demo_retry_fatal_error` | Retry fatal errors | `fatal_error` predicate |
| 20 | `demo_spawn_loop_retry_exponential` | Continuous service loop | `spawn_loop`, `IterResult` |

#### Concurrency Control

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 11 | `demo_semaphore` | Semaphore rate limiting | `Semaphore`, `acquire`, `release` |
| 17 | `demo_semaphore_try_acquire` | Semaphore non-blocking acquisition | `try_acquire()` |

#### Queues and Pipelines

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 15 | `demo_queue_pipeline` | Queue pipeline | `Queue`, `put`, `get` |
| 18 | `demo_queue_mpmc` | Multi-producer/multi-consumer queue | MPMC pattern |
| 24 | `demo_queue_try_get_nonblocking` | Queue non-blocking read | `try_get()`, `pause()` |

#### Business Integration Scenario

| Example | Function Name | Description | Core Concept |
|---------|--------------|-------------|-------------|
| 25 | `demo_business_checkout_flow` | Business integration scenario - order and payment flow | Combined use of timeout, retry, error handling |

### How to Find Examples

1. **Search by Function**: Use the tables above to quickly locate needed functionality
2. **Search Code**: Search for function names in `src/Async_best_practices.mbt`
3. **View Tests**: Check corresponding test cases in `src/Async_best_practices_test.mbt`
4. **Read Documentation**: Each function has detailed `///|` comments explaining usage and best practices

### Example Code Structure

Each example follows this structure:

```moonbit
///|
/// Example N: Title - Brief Description
/// 
/// Detailed explanation of the example's purpose and usage scenarios.
/// 
/// # Best Practices
/// - List key best practice points
/// - Explain when to use this pattern
/// 
/// # Example
/// ```moonbit no-check
/// let result = example_function()
/// // Explain expected result
/// ```
pub async fn example_function() -> String {
  // Implementation code
  "result"
}
```

Running tests for these examples shows event timelines and expected outputs intuitively.

## 🛠️ Development Guide

### Running Tests

```bash
# Run all tests
moon test --target native

# Run and update snapshots (if behavior changes)
moon test --target native --update

# Run specific test (if supported)
moon test --target native --filter "test_name"
```

### Common Commands

```bash
# Update interface files
moon info

# Format code
moon fmt

# Static checking
moon check

# View coverage
moon coverage analyze > uncovered.log
```

### Target Notes

- **Recommended to use `--target native`**: Upstream `moonbitlang/async` uses C FFI internally, `wasm-gc` is currently not supported
- **For WASM/JS targets**: Replace dependencies as needed or wait for upstream support

## 📖 Learning Path

### Beginner Path

1. **Step 1**: Read this README to understand project structure
2. **Step 2**: Run tests to see example output: `moon test --target native`
3. **Step 3**: Start with beginner examples (1-8), read code and comments one by one
4. **Step 4**: Read `docs/best_practices.mbt.md` to understand design philosophy
5. **Step 5**: Try applying these patterns in your own project

### Advanced Path

1. **Deep Understanding**: Read advanced examples (9-25) to understand complex scenarios
2. **Best Practices**: Read detailed explanations in `docs/best_practices.mbt.md`
3. **Business Application**: Reference `demo_business_checkout_flow` to learn how to combine usage
4. **Source Code Learning**: Check upstream `moonbitlang/async` source code implementation

### AI Code Assistant Usage

If you use AI code assistants (such as Cursor, Claude Code, GitHub Copilot, etc.):

1. **Reference AGENTS.md**: This repository includes an `AGENTS.md` file to help AI understand project structure
2. **Reference Examples**: Reference specific example function names in prompts, AI can quickly understand your needs
3. **Read Documentation Comments**: Each function has detailed documentation comments from which AI can learn best practices

## Publishing to Mooncakes (Optional)

If you fork/modify this repository and want to distribute it as a module:

1) Modify `moon.mod.json`:

```json
{
  "name": "yourname/async-best-practices",
  "repository": "https://github.com/yourname/async-best-practices"
}
```

2) Ensure `README.mbt.md` is the entry documentation (this repository already configures the `readme` field).

3) After configuring credentials in Mooncakes, execute the publish command (follow official guidelines), usually:

```bash
moon publish
```

Note: The `name` prefix must be your Mooncakes username; it's recommended to use lowercase hyphenated style for repository and module names.

## 📚 Further Reading

### In-Project Documentation

- **`src/Async_best_practices.mbt`**: Implementation code for all examples, learn concise idiomatic writing
- **`src/Async_best_practices_test.mbt`**: Test cases, understand how to verify async code
- **`docs/best_practices.mbt.md`**: Systematic best practices guide with design philosophy and detailed explanations
- **`AGENTS.md`**: AI code assistant guide to help AI understand project structure and usage

### External Resources

- **MoonBit Official Documentation**: [https://docs.moonbitlang.com](https://docs.moonbitlang.com)
- **Async Library Source Code**: Reference more advanced IO/HTTP/process control examples in upstream `.mooncakes/moonbitlang/async/`
- **MoonBit Community**: Participate in MoonBit community discussions for more help

## 🤝 Contributing

Contributions are welcome! If you have:

- New examples or best practices
- Documentation improvement suggestions
- Bug reports or fixes

Please submit an Issue or Pull Request.

## 📄 License

This project is licensed under the Apache-2.0 License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Thanks to the developers of the `moonbitlang/async` library
- Referenced documentation style from [moonbitlang/system-prompt](https://github.com/moonbitlang/system-prompt)

