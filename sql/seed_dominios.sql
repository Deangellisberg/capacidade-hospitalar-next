-- seed_dominios.sql
-- Popula os domínios que ficaram vazios após a criação do schema (falha silenciosa
-- do psql -f, sem ON_ERROR_STOP). Rode uma vez, na ordem em que está aqui.

INSERT INTO dom_tipo_leito (tp_leito, categoria) VALUES
    ('1', 'Cirúrgico'),
    ('2', 'Clínico'),
    ('3', 'Complementar'),
    ('4', 'Obstétricos'),
    ('5', 'Pediátricos'),
    ('6', 'Outras Especialidades'),
    ('7', 'Hospital Dia');

INSERT INTO dom_codigo_leito (codleito, especialidade) VALUES
    ('01', 'Buco Maxilo Facial'),
    ('02', 'Cardiologia'),
    ('03', 'Cirurgia Geral'),
    ('04', 'Endocrinologia'),
    ('05', 'Gastroenterologia'),
    ('06', 'Ginecologia'),
    ('07', 'Cirúrgico/Diagnóstico/Terapêutico'),
    ('08', 'Nefrologia/Urologia'),
    ('09', 'Neurocirurgia'),
    ('10', 'Obstetricia Cirurgica'),
    ('11', 'Oftalmologia'),
    ('12', 'Oncologia'),
    ('13', 'Ortopedia/Traumatologia'),
    ('14', 'Otorrinolaringologia'),
    ('15', 'Plastica'),
    ('16', 'Toracica'),
    ('31', 'Aids'),
    ('32', 'Cardiologia'),
    ('33', 'Clinica Geral'),
    ('34', 'Cronicos'),
    ('35', 'Dermatologia'),
    ('36', 'Geriatria'),
    ('37', 'Hansenologia'),
    ('38', 'Hematologia'),
    ('40', 'Nefrourologia'),
    ('41', 'Neonatologia'),
    ('42', 'Neurologia'),
    ('43', 'Obstetricia Clinica'),
    ('44', 'Oncologia'),
    ('45', 'Pediatria Clinica'),
    ('46', 'Pneumologia'),
    ('47', 'Psiquiatria'),
    ('48', 'Reabilitacao'),
    ('49', 'Pneumologia Sanitaria'),
    ('64', 'Unidade Intermediaria'),
    ('65', 'Unidade Intermediaria Neonatal'),
    ('66', 'Unidade Isolamento'),
    ('67', 'Transplante'),
    ('68', 'Pediatria Cirurgica'),
    ('69', 'Aids'),
    ('70', 'Fibrose Cistica'),
    ('71', 'Intercorrencia Pos-Transplante'),
    ('72', 'Geriatria'),
    ('73', 'Saude Mental'),
    ('74', 'Uti Adulto - Tipo I'),
    ('75', 'Uti Adulto - Tipo Ii'),
    ('76', 'Uti Adulto - Tipo Iii'),
    ('77', 'Uti Pediatrica - Tipo I'),
    ('78', 'Uti Pediatrica - Tipo Ii'),
    ('79', 'Uti Pediatrica - Tipo Iii'),
    ('80', 'Uti Neonatal - Tipo I'),
    ('81', 'Uti Neonatal - Tipo Ii'),
    ('82', 'Uti Neonatal - Tipo Iii'),
    ('83', 'Uti De Queimados'),
    ('84', 'Acolhimento Noturno'),
    ('85', 'Uti Coronariana Tipo Ii - Uco Tipo Ii'),
    ('86', 'Uti Coronariana Tipo Iii - Uco Tipo Iii'),
    ('87', 'Saude Mental'),
    ('88', 'Queimado Adulto'),
    ('89', 'Queimado Pediatrico'),
    ('90', 'Queimado Adulto'),
    ('91', 'Queimado Pediatrico'),
    ('92', 'Unidade De Cuidados Intermediarios Neonatal Convencional'),
    ('93', 'Unidade De Cuidados Intermediarios Neonatal Canguru'),
    ('94', 'Unidade De Cuidados Intermediarios Pediatrico'),
    ('95', 'Unidade De Cuidados Intermediarios Adulto');

INSERT INTO dom_especialidade_sih (espec, especialidade) VALUES
    ('01', 'Cirurgia geral'),
    ('02', 'Obstetrícia'),
    ('03', 'Clínica médica'),
    ('04', 'Crônico e FPT'),
    ('05', 'Psiquiatria'),
    ('06', 'Tisiologia'),
    ('07', 'Pediatria'),
    ('08', 'Reabilitação'),
    ('09', 'Psiquiatria - hospital/dia');

INSERT INTO dom_tipo_aih (ident, significado) VALUES
    ('1', 'AIH Normal'),
    ('5', 'AIH de Longa Permanencia e FTP');

-- Retry: agora que os domínios existem, o INSERT abaixo (que falhou antes) funciona.
-- Se já tiver essas 2 linhas (rodou com sucesso antes), o ON CONFLICT evita erro de duplicata.
INSERT INTO de_para_especialidade_leito (espec, tp_leito) VALUES
    ('01', '1'),
    ('03', '2')
ON CONFLICT (espec) DO NOTHING;
