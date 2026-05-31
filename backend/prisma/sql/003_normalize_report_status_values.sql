update public.reports
set status = 'suspected_spam'
where status::text = 'suspected spam';
