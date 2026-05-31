insert into public.categories (id, name, description)
values
  (1, 'Jalan Berlubang', 'Kerusakan permukaan jalan yang berisiko bagi pengguna jalan'),
  (2, 'Lampu Jalan Mati', 'Penerangan jalan umum tidak berfungsi'),
  (3, 'Rambu Rusak', 'Rambu lalu lintas rusak, hilang, atau tidak terlihat'),
  (4, 'Trotoar Rusak', 'Trotoar retak, berlubang, atau tidak aman dilalui'),
  (5, 'Kemacetan/Penghalang Jalan', 'Hambatan jalan yang perlu ditindaklanjuti'),
  (6, 'Drainase Tersumbat', 'Saluran air tersumbat atau rusak sehingga mengganggu jalan'),
  (7, 'Lampu Lalu Lintas Rusak', 'Traffic light mati, error, atau tidak sinkron'),
  (8, 'Marka Jalan Pudar', 'Marka jalan tidak terlihat jelas atau perlu pengecatan ulang'),
  (9, 'Jembatan/Pagar Pengaman Rusak', 'Kerusakan jembatan kecil, guardrail, atau pagar pengaman jalan'),
  (10, 'Lainnya', 'Masalah infrastruktur jalan lain yang belum masuk kategori utama')
on conflict (id) do update
set name = excluded.name,
    description = excluded.description,
    is_active = true;
