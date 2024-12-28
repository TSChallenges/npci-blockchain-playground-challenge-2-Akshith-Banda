// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Payroll {
    address public companyAcc;
    uint256 public companyBal;
    uint256 public totalEmployees = 0;
    uint256 public totalSalary = 0;
    uint256 public lastPaymentTime; // Time of last payment
    uint256 public paymentInterval = 30 days; // Example payment interval (can be modified)
    
    mapping(address => bool) isEmployee;
    mapping(address => uint256) public lastPaid;

    event Paid(uint256 id, address from, uint256 totalSalary, uint256 timestamp);
    event EmployeeAdded(uint256 id, address worker, uint256 salary);
    event PaymentScheduled(uint256 nextPaymentTime);

    struct Employee {
        uint256 id;
        address worker;
        uint256 salary;
        uint256 timestamp;
        bool isActive;
    }

    Employee[] employees;

    modifier onlyCompanyOwner() {
        require(msg.sender == companyAcc, "Only company owner can perform this action");
        _;
    }

    modifier onlyActiveEmployees() {
        require(isEmployee[msg.sender] && employees[getEmployeeIndex(msg.sender)].isActive, "Only active employees can access this");
        _;
    }

    constructor() {
        companyAcc = msg.sender;
        lastPaymentTime = block.timestamp; // Set the initial payment time to now
    }

    // Add a new employee with a salary and check if the employee already exists
    function addEmployee(address worker, uint256 salary) external onlyCompanyOwner {
        require(worker != address(0), "Invalid employee address");
        require(!isEmployee[worker], "Employee already exists");
        require(salary > 0, "Salary must be greater than zero");

        employees.push(Employee({
            id: totalEmployees,
            worker: worker,
            salary: salary,
            timestamp: block.timestamp,
            isActive: true
        }));

        isEmployee[worker] = true;
        totalEmployees++;
        totalSalary += salary;

        emit EmployeeAdded(totalEmployees - 1, worker, salary);
    }

    // Deactivate an employee (e.g., termination or leave)
    function deactivateEmployee(address worker) external onlyCompanyOwner {
        uint256 index = getEmployeeIndex(worker);
        require(employees[index].isActive, "Employee is already inactive");
        
        employees[index].isActive = false;
        totalSalary -= employees[index].salary;

    }

    // Check if the payment interval has elapsed since the last payment
    function isPaymentIntervalElapsed() public view returns (bool) {
        return block.timestamp >= lastPaymentTime + paymentInterval;
    }

    // Process batch payments securely and prevent reentrancy attacks
    function processPayments() external onlyCompanyOwner {
        require(isPaymentIntervalElapsed(), "Payment interval has not elapsed");
        require(companyBal >= totalSalary, "Insufficient company balance");

        for (uint256 i = 0; i < employees.length; i++) {
            Employee storage employee = employees[i];
            if (employee.isActive) {
                sendPayment(employee.worker, employee.salary);
                lastPaid[employee.worker] = block.timestamp;
                emit Paid(employee.id, companyAcc, employee.salary, block.timestamp);
            }
        }

        lastPaymentTime = block.timestamp;
        
    }

    // Allow the company owner to fund the company balance and track it
    function fundCompany() external payable onlyCompanyOwner {
        require(msg.value > 0, "Funding amount must be greater than zero");
        companyBal += msg.value;
    }

    // Allow the company owner to update the payment interval dynamically
    function updatePaymentInterval(uint256 newInterval) external onlyCompanyOwner {
        require(newInterval > 0, "Payment interval must be greater than zero");
        paymentInterval = newInterval;
    }

    // Internal function to securely send money to an employee, preventing reentrancy attacks
    function sendPayment(address employee, uint256 amount) internal {
        require(companyBal >= amount, "Insufficient funds to pay employee");
        companyBal -= amount;

        // Send the payment
        address payable receipient = payable(employee);
        receipient.transfer(amount);
        // (bool success, ) = employee.call{value: amount}("");
        // require(success, "Payment transfer failed");
    }

    // Helper function to get an employee's index by their address
    function getEmployeeIndex(address worker) internal view returns (uint256) {
        for (uint256 i = 0; i < employees.length; i++) {
            if (employees[i].worker == worker) {
                return i;
            }
        }
        revert("Employee not found");
    }

    // Function to terminate the contract and transfer remaining funds to the company owner
    function terminateContract() external onlyCompanyOwner {

        address payable receipient = payable(companyAcc);
        receipient.transfer(companyBal);

        companyBal = 0;

         selfdestruct(payable(companyAcc));
    }

    function getEmployees() external view returns (Employee[] memory) {
        return employees;
    }
}
