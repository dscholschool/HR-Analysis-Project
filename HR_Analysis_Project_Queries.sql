--1. Chảy máu chất xám: Bao nhiêu người đã rời đi? Bộ phận nào đang là "điểm nóng" có tỷ lệ nghỉ việc cao nhất?
SELECT Department, SUM(CASE WHEN Exit_Date IS NOT NULL THEN 1 ELSE 0 END) AS Resigned_Staff, 
		ROUND( SUM(CASE WHEN Exit_Date IS NOT NULL THEN 1.0 ELSE 0 END) / COUNT(Employee_Id) * 100, 2) AS Turnover_Rate_Percent
FROM Employee GROUP BY Department ORDER BY Turnover_Rate_Percent DESC
--2. Cân bằng thu nhập: Mức lương trung bình theo cấp độ công việc? Phòng ban nào đang nhận đãi ngộ tốt nhất?
--2.1. Mức lương trung bình theo cấp độ công việc
select Job_Level, ROUND(AVG(Base_Salary_Annual),0) as average_salary from Employee 
group by Job_Level order by average_salary desc
--2.2. Phòng ban nào đang nhận đãi ngộ tốt nhất?
select Department, ROUND(AVG(Base_Salary_Annual),0) as average_salary from Employee
group by Department order by average_salary
--3. Điểm rơi phong độ: Những tháng nào trong năm nhân viên đạt hiệu suất "đỉnh" nhất?
create procedure sp_perform (@year int)
as
begin
	select MONTH(Year_Month) as 'Month', ROUND(AVG(Performance_Rating),2) as 'Average Performance Rating' from Performance 
	where YEAR(Year_Month) = @year 
	group by MONTH(Year_Month) order by 'Average Performance Rating' desc
end

exec sp_perform 2022
exec sp_perform 2024
--4. Lãnh đạo tài ba: Vinh danh 10 quản lý có điểm hiệu suất trung bình của đội nhóm cao nhất.
select top 10 Manager_Id, Manager_Name, COUNT(e.Employee_Id) as 'Team Size', ROUND(AVG(Performance_Rating),3) as 'Team Average Performance Rating' 
from Employee e join Performance p on e.Employee_Id = p.Employee_Id where Manager_Id is not null
group by Manager_Id, Manager_Name having COUNT(distinct e.Employee_Id) >=3  order by [Team Average Performance Rating] desc
--5. Học tập & Phát triển: Liệu đổ tiền vào đào tạo có hiệu quả? Nhân viên học nhiều hơn có làm việc tốt hơn không?
WITH Employee_Stats AS (
    -- Tính tổng giờ học và hiệu suất của từng nhân viên
    SELECT 
        Employee_Id, 
        SUM(Training_Hours) AS Total_Training_Hours,
        AVG(Performance_Rating) AS Avg_Performance
    FROM Performance
    GROUP BY Employee_Id
),
Company_Avg AS (
    -- Lấy mốc Trung bình tổng giờ học của toàn công ty
    SELECT AVG(Total_Training_Hours) AS Avg_Total_Hours FROM Employee_Stats
),
Classified_Employees AS (
    -- Gắn nhãn cho TỪNG người trước khi gom nhóm 
    SELECT 
        E.Employee_Id,
        E.Avg_Performance,
        CASE 
            WHEN E.Total_Training_Hours >= C.Avg_Total_Hours THEN 'Train Much (Above Average)'
            ELSE 'Train Little (Below Average)'
        END AS Training_Frequency
    FROM Employee_Stats E
    CROSS JOIN Company_Avg C
)

-- Gom nhóm theo nhãn vừa tạo 
SELECT 
    Training_Frequency,
    COUNT(Employee_Id) AS Total_Employees,
    ROUND(AVG(Avg_Performance), 2) AS Group_Avg_Performance
FROM Classified_Employees
GROUP BY Training_Frequency
ORDER BY Group_Avg_Performance DESC
--6. Giải mã Top Store: 5 cửa hàng doanh thu cao nhất là ai? Điều gì tạo nên sự khác biệt giữa họ và nhóm thấp nhất?
select top 5 s.Store_Id, Store_Name, ROUND(AVG(Customer_Satisfaction),3) as Average_Customer_Satisfaction, SUM(Sales_Actual) as Total_Sales
from Store s join Business_Outcomes b on s.Store_Id = b.Store_Id 
group by s.Store_Id, Store_Name order by Total_Sales desc
--7. Chỉ số hạnh phúc: Bộ phận nào đang "hạnh phúc" nhất công ty?
select Department, ROUND(AVG(Employee_Satisfaction),3) as Average_Employee_Satisfaction 
from Employee e join Performance p on e.Employee_Id = p.Employee_Id
group by Department order by Average_Employee_Satisfaction desc
--8. Quy hoạch nhân tài: Ai là ứng viên sáng giá nhất cho đợt thăng tiến tới dựa trên Performance và Satisfaction?
select top 5 e.Employee_Id, Full_Name, Department, AVG(Performance_Rating) as Average_Performance_Rating, AVG(Employee_Satisfaction) as Average_Satisfaction
from Employee e join Performance p on e.Employee_Id = p.Employee_Id where Exit_Date is not null
group by e.Employee_Id, Full_Name, Department order by Average_Performance_Rating desc, Average_Satisfaction desc
--9. Khoảng cách thế hệ: Mối quan hệ giữa độ tuổi và hiệu suất? Nhân viên trẻ hay lớn tuổi đang "gánh team"?
select 
	case 
	when Age <30 then 'U30'
	when Age between 30 and 40 then 'U40'
	else 'Old'
	end as Age_group,
	ROUND(AVG(Performance_Rating),3) as Average_Performance_Rating
from Employee e join Performance p on e.Employee_Id = p.Employee_Id
group by 
	(case 
	when Age <30 then 'U30'
	when Age between 30 and 40 then 'U40'
	else 'Old'
	end)
order by Average_Performance_Rating desc