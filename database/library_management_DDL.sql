use master
go

if db_id('library_managementDB') is not null
begin
    alter database library_managementDB set single_user with rollback immediate
    drop database library_managementDB
end
go

create database library_managementDB
go

use library_managementDB
go

-- schema
create schema library
go

-- core tables
create table library.Members
(
    MemberID int identity primary key,
    MemberName varchar(100) not null,
    Phone varchar(20) not null check (len(Phone) = 11 and Phone not like '%[^0-9]%'),
    Address varchar(200),
    Email varchar(100),
    JoinDate date not null default getdate(),
    IsActive bit not null default 1
)
go

create table library.Authors
(
    AuthorID int identity primary key,
    AuthorName varchar(100) not null,
    Country varchar(60)
)
go

create table library.Categories
(
    CategoryID int identity primary key,
    CategoryName varchar(100) not null unique
)
go

create table library.Publishers
(
    PublisherID int identity primary key,
    PublisherName varchar(100) not null unique
)
go

create table library.Books
(
    BookID int identity primary key,
    BookName varchar(150) not null,
    AuthorID int,
    CategoryID int,
    PublisherID int,
    Price money check (Price > 0),
    publishedYear int,
    ISBN varchar(20),
    Edition varchar(30),
    Language varchar(30) default 'English',
    Pages int check (Pages is null or Pages > 0),
    Description varchar(500),
    IsActive bit not null default 1,

    foreign key (AuthorID) references library.Authors(AuthorID),
    foreign key (CategoryID) references library.Categories(CategoryID),
    foreign key (PublisherID) references library.Publishers(PublisherID)
)
go

create table library.BookCopies
(
    CopyID int identity primary key,
    BookID int not null references library.Books(BookID),
    AccessionNo varchar(30) not null unique,
    Quantity int check (Quantity >= 0) default 1,
    Status varchar(20) not null default 'available'
        check (Status in ('available','issued','damaged','lost','maintenance'))
)
go

create table library.IssueBooks
(
    IssueID int identity primary key,
    MemberID int not null,
    BookID int not null,
    CopyID int,
    IssueDate date not null default getdate(),
    DueDate date not null,

    foreign key (MemberID) references library.Members(MemberID),
    foreign key (BookID) references library.Books(BookID),
    foreign key (CopyID) references library.BookCopies(CopyID),
    constraint CK_IssueBooks_DueDate check (DueDate >= IssueDate)
)
go

create table library.ReturnBooks
(
    ReturnID int identity primary key,
    IssueID int not null unique references library.IssueBooks(IssueID),
    ReturnDate date not null default getdate(),
    Fine money not null default 0 check (Fine >= 0),
    Condition varchar(20) not null default 'good'
        check (Condition in ('good','damaged','lost'))
)
go

-- new tables
create table library.Librarians
(
    LibrarianID int identity primary key,
    LibrarianName varchar(100) not null,
    Phone varchar(20),
    Email varchar(100),
    Username varchar(50) not null unique,
    PasswordHash varchar(255),
    IsActive bit not null default 1,
    CreatedAt datetime2 not null default sysdatetime()
)
go

create table library.BookAuthors
(
    BookID int not null,
    AuthorID int not null,
    constraint PK_BookAuthors primary key (BookID, AuthorID),
    foreign key (BookID) references library.Books(BookID),
    foreign key (AuthorID) references library.Authors(AuthorID)
)
go

create table library.Reservations
(
    ReservationID int identity primary key,
    MemberID int not null,
    BookID int not null,
    ReservationDate datetime2 not null default sysdatetime(),
    Status varchar(20) not null default 'pending'
        check (Status in ('pending','fulfilled','cancelled')),
    FulfilledDate datetime2,
    foreign key (MemberID) references library.Members(MemberID),
    foreign key (BookID) references library.Books(BookID)
)
go

create table library.FinePayments
(
    PaymentID int identity primary key,
    ReturnID int not null references library.ReturnBooks(ReturnID),
    Amount money not null check (Amount > 0),
    PaymentDate datetime2 not null default sysdatetime(),
    PaymentMethod varchar(20) not null default 'cash'
        check (PaymentMethod in ('cash','card','mobile','bank')),
    ReceivedBy int references library.Librarians(LibrarianID)
)
go

create table library.BookDamage
(
    DamageID int identity primary key,
    CopyID int not null references library.BookCopies(CopyID),
    DamageType varchar(30) not null
        check (DamageType in ('damaged','lost')),
    Description varchar(300),
    ReportedDate date not null default getdate(),
    Cost money not null default 0 check (Cost >= 0),
    Status varchar(20) not null default 'open'
        check (Status in ('open','resolved'))
)
go

create table library.AuditLogs
(
    AuditID bigint identity primary key,
    TableName varchar(100) not null,
    ActionName varchar(20) not null,
    RecordID int,
    UserName varchar(100) default suser_sname(),
    ActionDate datetime2 not null default sysdatetime(),
    OldValue varchar(max),
    NewValue varchar(max)
)
go

-- indexes
create index IX_IssueBooks_DueDate on library.IssueBooks(DueDate)
create index IX_IssueBooks_MemberID on library.IssueBooks(MemberID)
create index IX_IssueBooks_BookID on library.IssueBooks(BookID)
create index IX_Books_BookName on library.Books(BookName)
create index IX_Books_AuthorID on library.Books(AuthorID)
create index IX_Books_CategoryID on library.Books(CategoryID)
create index IX_Reservations_BookID_Status on library.Reservations(BookID, Status)
create index IX_FinePayments_ReturnID on library.FinePayments(ReturnID)
go

-- views
create view library.vw_MemberIssueDetails
as
select
    m.MemberID,
    m.MemberName,
    b.BookID,
    b.BookName,
    i.IssueID,
    i.IssueDate,
    i.DueDate,
    case
        when r.ReturnID is not null then 'returned'
        when i.DueDate < cast(getdate() as date) then 'late'
        else 'issued'
    end as IssueStatus
from library.IssueBooks i
join library.Members m on m.MemberID = i.MemberID
join library.Books b on b.BookID = i.BookID
left join library.ReturnBooks r on r.IssueID = i.IssueID
go

create view library.vw_AvailableBooks
as
select
    b.BookID,
    b.BookName,
    a.AuthorName,
    c.CategoryName,
    p.PublisherName,
    b.Price,
    b.ISBN,
    sum(case when bc.Status = 'available' then bc.Quantity else 0 end) as AvailableQuantity
from library.Books b
left join library.Authors a on a.AuthorID = b.AuthorID
left join library.Categories c on c.CategoryID = b.CategoryID
left join library.Publishers p on p.PublisherID = b.PublisherID
left join library.BookCopies bc on bc.BookID = b.BookID
where b.IsActive = 1
group by
    b.BookID, b.BookName, a.AuthorName, c.CategoryName,
    p.PublisherName, b.Price, b.ISBN
go

create view library.vw_LateBooks
as
select
    i.IssueID,
    m.MemberID,
    m.MemberName,
    b.BookID,
    b.BookName,
    i.IssueDate,
    i.DueDate,
    datediff(day, i.DueDate, cast(getdate() as date)) as LateDays,
    datediff(day, i.DueDate, cast(getdate() as date)) * 5 as CurrentFine
from library.IssueBooks i
join library.Members m on m.MemberID = i.MemberID
join library.Books b on b.BookID = i.BookID
left join library.ReturnBooks r on r.IssueID = i.IssueID
where r.ReturnID is null
  and i.DueDate < cast(getdate() as date)
go

create view library.vw_MemberFineBalance
as
select
    m.MemberID,
    m.MemberName,
    isnull(sum(r.Fine),0) as TotalFine,
    isnull(sum(p.PaidAmount),0) as TotalPaid,
    isnull(sum(r.Fine),0) - isnull(sum(p.PaidAmount),0) as DueAmount
from library.Members m
left join library.IssueBooks i on i.MemberID = m.MemberID
left join library.ReturnBooks r on r.IssueID = i.IssueID
left join
(
    select ReturnID, sum(Amount) as PaidAmount
    from library.FinePayments
    group by ReturnID
) p on p.ReturnID = r.ReturnID
group by m.MemberID, m.MemberName
go

create view library.vw_BookAuthors
as
select
    b.BookID,
    b.BookName,
    a.AuthorID,
    a.AuthorName
from library.BookAuthors ba
join library.Books b on b.BookID = ba.BookID
join library.Authors a on a.AuthorID = ba.AuthorID
go

-- procedures
create proc library.sp_IssueBook
    @MemberID int,
    @BookID int,
    @CopyID int = null,
    @Days int = 30
as
begin
    set nocount on
    set xact_abort on

    begin try
        begin tran

        if not exists
        (
            select 1 from library.Members
            where MemberID = @MemberID and IsActive = 1
        )
            throw 50001, 'member not active', 1

        if not exists
        (
            select 1 from library.Books
            where BookID = @BookID and IsActive = 1
        )
            throw 50002, 'book not active', 1

        if exists
        (
            select 1 from library.IssueBooks i
            left join library.ReturnBooks r on r.IssueID = i.IssueID
            where i.MemberID = @MemberID
              and i.BookID = @BookID
              and r.ReturnID is null
        )
            throw 50003, 'member already has this book', 1

        declare @SelectedCopyID int

        if @CopyID is not null
        begin
            if not exists
            (
                select 1
                from library.BookCopies
                where CopyID = @CopyID
                  and BookID = @BookID
                  and Status = 'available'
                  and Quantity > 0
            )
                throw 50004, 'copy not available', 1

            set @SelectedCopyID = @CopyID
        end
        else
        begin
            select top 1 @SelectedCopyID = CopyID
            from library.BookCopies
            where BookID = @BookID
              and Status = 'available'
              and Quantity > 0
            order by CopyID
        end

        if @SelectedCopyID is null
            throw 50005, 'book not available', 1

        insert into library.IssueBooks(MemberID, BookID, CopyID, IssueDate, DueDate)
        values(@MemberID, @BookID, @SelectedCopyID, cast(getdate() as date),
               dateadd(day, @Days, cast(getdate() as date)))

        update library.BookCopies
        set Quantity = Quantity - 1,
            Status = case when Quantity - 1 <= 0 then 'issued' else Status end
        where CopyID = @SelectedCopyID

        commit
    end try
    begin catch
        if xact_state() <> 0 rollback
        throw
    end catch
end
go

create proc library.sp_ReturnBook
    @IssueID int,
    @Condition varchar(20) = 'good'
as
begin
    set nocount on
    set xact_abort on

    begin try
        begin tran

        declare
            @BookID int,
            @CopyID int,
            @DueDate date,
            @Fine money,
            @ReturnDate date = cast(getdate() as date)

        select
            @BookID = BookID,
            @CopyID = CopyID,
            @DueDate = DueDate
        from library.IssueBooks
        where IssueID = @IssueID

        if @DueDate is null
            throw 50006, 'issue not found', 1

        if exists(select 1 from library.ReturnBooks where IssueID = @IssueID)
            throw 50007, 'book already returned', 1

        set @Fine =
            case
                when @ReturnDate > @DueDate
                    then datediff(day, @DueDate, @ReturnDate) * 5
                else 0
            end

        insert into library.ReturnBooks(IssueID, ReturnDate, Fine, Condition)
        values(@IssueID, @ReturnDate, @Fine, @Condition)

        if @CopyID is not null
        begin
            update library.BookCopies
            set
                Quantity = case when @Condition = 'good' then Quantity + 1 else Quantity end,
                Status =
                    case
                        when @Condition = 'damaged' then 'damaged'
                        when @Condition = 'lost' then 'lost'
                        else 'available'
                    end
            where CopyID = @CopyID
        end

        commit
    end try
    begin catch
        if xact_state() <> 0 rollback
        throw
    end catch
end
go

create proc library.sp_PayFine
    @ReturnID int,
    @Amount money,
    @PaymentMethod varchar(20) = 'cash',
    @LibrarianID int = null
as
begin
    set nocount on

    declare @Fine money, @Paid money

    select @Fine = Fine
    from library.ReturnBooks
    where ReturnID = @ReturnID

    if @Fine is null
        throw 50008, 'return record not found', 1

    select @Paid = isnull(sum(Amount),0)
    from library.FinePayments
    where ReturnID = @ReturnID

    if @Amount <= 0 or @Amount > @Fine - @Paid
        throw 50009, 'invalid payment amount', 1

    insert into library.FinePayments(ReturnID, Amount, PaymentMethod, ReceivedBy)
    values(@ReturnID, @Amount, @PaymentMethod, @LibrarianID)
end
go

create proc library.sp_ReserveBook
    @MemberID int,
    @BookID int
as
begin
    set nocount on

    if not exists(select 1 from library.Members where MemberID = @MemberID and IsActive = 1)
        throw 50010, 'member not active', 1

    if not exists(select 1 from library.Books where BookID = @BookID and IsActive = 1)
        throw 50011, 'book not active', 1

    if exists
    (
        select 1 from library.Reservations
        where MemberID = @MemberID
          and BookID = @BookID
          and Status = 'pending'
    )
        throw 50012, 'reservation already exists', 1

    insert into library.Reservations(MemberID, BookID)
    values(@MemberID, @BookID)
end
go

create proc library.sp_CancelReservation
    @ReservationID int
as
begin
    set nocount on

    update library.Reservations
    set Status = 'cancelled'
    where ReservationID = @ReservationID
      and Status = 'pending'

    if @@rowcount = 0
        throw 50013, 'pending reservation not found', 1
end
go

create proc library.sp_SearchBooks
    @Search varchar(150) = null,
    @CategoryID int = null,
    @AuthorID int = null,
    @PageNumber int = 1,
    @PageSize int = 10
as
begin
    set nocount on

    if @PageNumber < 1 set @PageNumber = 1
    if @PageSize < 1 set @PageSize = 10

    select
        b.BookID,
        b.BookName,
        a.AuthorName,
        c.CategoryName,
        b.Price,
        b.ISBN,
        b.Language
    from library.Books b
    left join library.Authors a on a.AuthorID = b.AuthorID
    left join library.Categories c on c.CategoryID = b.CategoryID
    where b.IsActive = 1
      and (@Search is null
           or b.BookName like '%' + @Search + '%'
           or b.ISBN like '%' + @Search + '%')
      and (@CategoryID is null or b.CategoryID = @CategoryID)
      and (@AuthorID is null or b.AuthorID = @AuthorID)
    order by b.BookID
    offset (@PageNumber - 1) * @PageSize rows
    fetch next @PageSize rows only
end
go

create proc library.sp_DeactivateMember
    @MemberID int
as
begin
    set nocount on
    update library.Members
    set IsActive = 0
    where MemberID = @MemberID
end
go

-- triggers
create trigger library.trg_Audit_Members
on library.Members
after insert, update, delete
as
begin
    set nocount on

    insert into library.AuditLogs(TableName, ActionName, RecordID, OldValue, NewValue)
    select
        'Members',
        case
            when exists(select 1 from inserted) and exists(select 1 from deleted) then 'update'
            when exists(select 1 from inserted) then 'insert'
            else 'delete'
        end,
        coalesce(i.MemberID, d.MemberID),
        case when d.MemberID is not null then
            concat('name=',d.MemberName,'; phone=',d.Phone,'; email=',d.Email) end,
        case when i.MemberID is not null then
            concat('name=',i.MemberName,'; phone=',i.Phone,'; email=',i.Email) end
    from inserted i
    full join deleted d on d.MemberID = i.MemberID
end
go

create trigger library.trg_Audit_Books
on library.Books
after insert, update, delete
as
begin
    set nocount on

    insert into library.AuditLogs(TableName, ActionName, RecordID, OldValue, NewValue)
    select
        'Books',
        case
            when exists(select 1 from inserted) and exists(select 1 from deleted) then 'update'
            when exists(select 1 from inserted) then 'insert'
            else 'delete'
        end,
        coalesce(i.BookID, d.BookID),
        case when d.BookID is not null then concat('name=',d.BookName,'; price=',d.Price) end,
        case when i.BookID is not null then concat('name=',i.BookName,'; price=',i.Price) end
    from inserted i
    full join deleted d on d.BookID = i.BookID
end
go

create trigger library.trg_BlockBookDelete
on library.Books
instead of delete
as
begin
    set nocount on

    if exists
    (
        select 1
        from library.IssueBooks i
        join deleted d on d.BookID = i.BookID
        left join library.ReturnBooks r on r.IssueID = i.IssueID
        where r.ReturnID is null
    )
        throw 50014, 'cannot delete a book with an active issue', 1

    delete bc
    from library.BookCopies bc
    join deleted d on d.BookID = bc.BookID

    delete ba
    from library.BookAuthors ba
    join deleted d on d.BookID = ba.BookID

    delete b
    from library.Books b
    join deleted d on d.BookID = b.BookID
end
go

create trigger library.trg_ReservationStatus
on library.Reservations
after update
as
begin
    set nocount on

    update r
    set FulfilledDate = sysdatetime()
    from library.Reservations r
    join inserted i on i.ReservationID = r.ReservationID
    where i.Status = 'fulfilled'
      and r.FulfilledDate is null
end
go

-- functions
create function library.fn_TotalBooksByMember(@MemberID int)
returns int
as
begin
    declare @Total int

    select @Total = count(*)
    from library.IssueBooks
    where MemberID = @MemberID

    return isnull(@Total,0)
end
go

create function library.fn_GetMemberIssues(@MemberID int)
returns table
as
return
(
    select
        i.IssueID,
        b.BookName,
        i.IssueDate,
        i.DueDate,
        case
            when r.ReturnID is not null then 'returned'
            when i.DueDate < cast(getdate() as date) then 'late'
            else 'issued'
        end as Status
    from library.IssueBooks i
    join library.Books b on b.BookID = i.BookID
    left join library.ReturnBooks r on r.IssueID = i.IssueID
    where i.MemberID = @MemberID
)
go

create function library.fn_LateReturnBooks(@Days int)
returns @Result table
(
    MemberName varchar(100),
    BookName varchar(150),
    LateDays int,
    CurrentFine money
)
as
begin
    insert into @Result
    select
        m.MemberName,
        b.BookName,
        datediff(day, i.DueDate, cast(getdate() as date)),
        datediff(day, i.DueDate, cast(getdate() as date)) * 5
    from library.IssueBooks i
    join library.Members m on m.MemberID = i.MemberID
    join library.Books b on b.BookID = i.BookID
    left join library.ReturnBooks r on r.IssueID = i.IssueID
    where r.ReturnID is null
      and datediff(day, i.DueDate, cast(getdate() as date)) > @Days

    return
end
go

create function library.fn_BookAvailable(@BookID int)
returns int
as
begin
    declare @Qty int

    select @Qty = isnull(sum(case when Status = 'available' then Quantity else 0 end),0)
    from library.BookCopies
    where BookID = @BookID

    return isnull(@Qty,0)
end
go
