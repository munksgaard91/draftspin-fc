-- Trøjenavne til banen: kælenavne (Gabriel, Alisson, Amad ...) og efternavne med partikler (Mac Allister, van de Ven ...).
alter table public.players add column if not exists short_name text;
update public.players set short_name = v.sn from (values
  ('Gabriel Magalhães','Gabriel'),('Juanlu Sanchez','Juanlu'),('Gonzalo Garcia','Gonzalo'),('Alisson Becker','Alisson'),('Amad Diallo','Amad'),('Jair Cunha','Jair'),('Reinildo Mandava','Reinildo'),
  ('Michele Di Gregorio','Di Gregorio'),('Sepp van den Berg','van den Berg'),('Maxim De Cuyper','De Cuyper'),('Luc De Fougerolles','De Fougerolles'),('Alexis Mac Allister','Mac Allister'),
  ('Emile Smith Rowe','Smith Rowe'),('Enzo Le Fee','Le Fee'),('Jocelin Ta Bi','Ta Bi'),('Micky van de Ven','van de Ven'),('Jorgen Strand Larsen','Strand Larsen')
) v(n, sn) where public.players.name = v.n;
