use library_managementDB
go

-- members
insert into library.Members(MemberName, Phone, Address, Email, JoinDate)
values
('Rahimul Islam','01710000001','Dhaka','rahim1@gmail.com','2026-01-10'),
('Karim Ahmed','01710000002','Chattogram','karim2@gmail.com','2026-01-11'),
('Zahid Hasan','01710000003','Sylhet','zahidh3@gmail.com','2026-01-12'),
('Mahfuzur Rahman','01710000004','Khulna','mahfuz4@gmail.com','2026-01-13'),
('Sumon Hossain','01710000005','Rajshahi','sumon5@gmail.com','2026-01-14'),
('Faruk Molla','01710000006','Barishal','faruk6@gmail.com','2026-01-15'),
('Nazmul Islam','01710000007','Dhaka','nazmul7@gmail.com','2026-01-16'),
('Tanvir Hossain','01710000008','Chattogram','tanvir8@gmail.com','2026-01-17'),
('Rashedul Alam','01710000009','Sylhet','rashed9@gmail.com','2026-01-18'),
('Saeed Hasan','01710000010','Khulna','saeed10@gmail.com','2026-01-19')
go

-- authors
insert into library.Authors(AuthorName, Country)
values
('Rabindranath Tagore','Bangladesh'),
('Selina Hossain','Bangladesh'),
('Humayun Ahmed','Bangladesh'),
('Kazi Nazrul Islam','Bangladesh'),
('George Orwell','UK'),
('J.K. Rowling','UK'),
('Mark Twain','USA'),
('Ernest Hemingway','USA'),
('Paulo Coelho','Brazil'),
('Agatha Christie','UK')
go

-- categories
insert into library.Categories(CategoryName)
values
('fiction'),('science'),('history'),('novel'),('poetry'),
('biography'),('mystery'),('fantasy'),('adventure'),('philosophy'),
('drama'),('horror'),('romance'),('thriller'),('self help'),
('motivation'),('technology'),('programming'),('religion'),('education')
go

-- publishers
insert into library.Publishers(PublisherName)
values
('bangla academy'),('penguin books'),('harpercollins'),
('oxford press'),('random house'),('simon & schuster'),
('scholastic'),('pearson'),('springer'),('wiley')
go

-- books
insert into library.Books
(BookName, AuthorID, CategoryID, PublisherID, Price, publishedYear, ISBN, Edition, Language, Pages, Description)
values
('gitanjali',1,5,1,500,1910,'9780000000001','1st','bengali',120,'poetry collection'),
('lal sobuj',2,1,1,400,1988,'9780000000002','1st','bengali',180,'fiction'),
('himu',3,4,1,350,1995,'9780000000003','1st','bengali',210,'novel'),
('bangabandhu memories',4,6,1,600,1975,'9780000000004','1st','bengali',250,'biography'),
('1984',5,17,2,650,1949,'9780000000005','2nd','english',328,'dystopian novel'),
('harry potter and the philosopher stone',6,8,7,800,1997,'9780000000006','1st','english',309,'fantasy novel'),
('adventures of tom sawyer',7,9,2,700,1876,'9780000000007','1st','english',274,'adventure novel'),
('the old man and the sea',8,1,2,750,1952,'9780000000008','1st','english',127,'classic fiction'),
('the alchemist',9,8,2,500,1988,'9780000000009','3rd','english',208,'fiction'),
('murder on the orient express',10,7,3,700,1934,'9780000000010','2nd','english',274,'mystery')
go

-- copies
insert into library.BookCopies(BookID, AccessionNo, Quantity, Status)
select BookID, concat('ac-',format(BookID,'000'),'-1'), 1, 'available'
from library.Books
go

-- authors
insert into library.BookAuthors(BookID, AuthorID)
select BookID, AuthorID
from library.Books
where AuthorID is not null
go

-- librarians
insert into library.Librarians(LibrarianName, Phone, Email, Username, PasswordHash)
values
('main librarian','01700000000','librarian@library.com','librarian1','change-this-hash')
go

-- issue examples
exec library.sp_IssueBook @MemberID = 1, @BookID = 1
exec library.sp_IssueBook @MemberID = 2, @BookID = 2
go

-- reserve example
exec library.sp_ReserveBook @MemberID = 3, @BookID = 1
go

-- basic queries
select * from library.Members
select * from library.Books
select * from library.vw_MemberIssueDetails
select * from library.vw_AvailableBooks
select * from library.vw_LateBooks
select * from library.vw_MemberFineBalance
select * from library.vw_BookAuthors
go

-- joins
select
    m.MemberName,
    b.BookName,
    i.IssueDate,
    i.DueDate
from library.IssueBooks i
join library.Members m on m.MemberID = i.MemberID
join library.Books b on b.BookID = i.BookID
go

select
    b.BookName,
    a.AuthorName,
    c.CategoryName,
    p.PublisherName
from library.Books b
left join library.Authors a on a.AuthorID = b.AuthorID
left join library.Categories c on c.CategoryID = b.CategoryID
left join library.Publishers p on p.PublisherID = b.PublisherID
go

-- subquery
select *
from library.Members
where MemberID in
(
    select MemberID
    from library.IssueBooks
)
go

-- correlated
select *
from library.Members m
where exists
(
    select 1
    from library.IssueBooks i
    where i.MemberID = m.MemberID
)
go

-- aggregate
select MemberID, count(*) as totalbooks
from library.IssueBooks
group by MemberID
go

select sum(Fine) as totalfine
from library.ReturnBooks
go

-- group having
select MemberID, count(*) as totalbooks
from library.IssueBooks
group by MemberID
having count(*) >= 1
go

-- case
select
    IssueID,
    case
        when DueDate < cast(getdate() as date) then 'late'
        when DueDate = cast(getdate() as date) then 'today'
        else 'on time'
    end as status
from library.IssueBooks
go

-- coalesce
select MemberName, coalesce(Email,'no email') as Email
from library.Members
go

-- string
select MemberName, len(MemberName) as namelength,
       upper(MemberName) as uppername,
       lower(MemberName) as lowername
from library.Members
go

-- date
select
    IssueID,
    datediff(day, IssueDate, DueDate) as totaldays,
    dateadd(day, 7, DueDate) as nextweek
from library.IssueBooks
go

-- pagination
select *
from library.Books
order by BookID
offset 0 rows fetch next 5 rows only
go

-- cte
with MemberBookCount as
(
    select MemberID, count(*) as totalbooks
    from library.IssueBooks
    group by MemberID
)
select *
from MemberBookCount
where totalbooks >= 1
go

-- derived table
select *
from
(
    select MemberID, count(*) as totalbooks
    from library.IssueBooks
    group by MemberID
) t
where totalbooks >= 1
go

-- window
select
    MemberID,
    count(*) as totalbooks,
    row_number() over(order by count(*) desc) as rowno,
    rank() over(order by count(*) desc) as bookrank,
    dense_rank() over(order by count(*) desc) as denserank
from library.IssueBooks
group by MemberID
go

-- running total
select
    ReturnID,
    Fine,
    sum(Fine) over(order by ReturnID rows between unbounded preceding and current row) as runningfine
from library.ReturnBooks
go

-- top books
select top 5
    b.BookID,
    b.BookName,
    count(i.IssueID) as issuecount
from library.Books b
left join library.IssueBooks i on i.BookID = b.BookID
group by b.BookID, b.BookName
order by issuecount desc
go

-- function
select library.fn_TotalBooksByMember(1) as totalbooks
select library.fn_BookAvailable(1) as availablecopies
select * from library.fn_GetMemberIssues(1)
select * from library.fn_LateReturnBooks(5)
go

-- search procedure
exec library.sp_SearchBooks @Search = 'the', @PageNumber = 1, @PageSize = 10
go

-- return
exec library.sp_ReturnBook @IssueID = 1, @Condition = 'good'
go

-- audit
select * from library.AuditLogs order by AuditID desc
go
