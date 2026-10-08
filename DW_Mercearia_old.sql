-- ============================================================
-- DATA WAREHOUSE - MERCEARIA
-- Modelo dimensional baseado no material "DW - Diniz"
-- Instituto Federal de Goiás / Inteligência em Negócios
--
-- Abordagem:
--   * Esquema Estrela (Star Schema)
--   * Fatos no maior nível de detalhe possível
--   * Dimensões desnormalizadas
--   * Chaves substitutas nas dimensões
--   * Dimensão Tempo
--   * Campos de controle de validade nas dimensões
--
-- Fatos:
--   F_VENDAS   -> granularidade: 1 linha por item de venda
--   F_COMPRAS  -> granularidade: 1 linha por item de compra
--
-- Dimensões:
--   D_TEMPO
--   D_PRODUTO
--   D_PESSOA  (usada como Cliente em F_VENDAS e Fornecedor em F_COMPRAS)
--
-- O script pressupõe que o banco OLTP da Mercearia esteja no schema public.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS mercearia_dw;

-- ============================================================
-- 1. LIMPEZA DO DW
-- ============================================================

DROP TABLE IF EXISTS mercearia_dw.f_vendas CASCADE;
DROP TABLE IF EXISTS mercearia_dw.f_compras CASCADE;
DROP TABLE IF EXISTS mercearia_dw.d_produto CASCADE;
DROP TABLE IF EXISTS mercearia_dw.d_pessoa CASCADE;
DROP TABLE IF EXISTS mercearia_dw.d_tempo CASCADE;

-- ============================================================
-- 2. DIMENSÃO TEMPO
-- ============================================================

CREATE TABLE mercearia_dw.d_tempo (
    sk_tempo            INTEGER PRIMARY KEY,
    data_completa       DATE NOT NULL UNIQUE,
    dia                 INTEGER NOT NULL,
    nome_dia_semana     VARCHAR(20) NOT NULL,
    numero_dia_semana   INTEGER NOT NULL,
    semana_ano          INTEGER NOT NULL,
    mes                 INTEGER NOT NULL,
    nome_mes            VARCHAR(20) NOT NULL,
    trimestre            INTEGER NOT NULL,
    semestre             INTEGER NOT NULL,
    ano                 INTEGER NOT NULL,
    inicio_mes          DATE NOT NULL,
    fim_mes             DATE NOT NULL,
    fim_semana           BOOLEAN NOT NULL
);

-- ============================================================
-- 3. DIMENSÃO PESSOA
--    Dimensão conformada: cliente nas vendas e fornecedor
--    nas compras.
-- ============================================================

CREATE TABLE mercearia_dw.d_pessoa (
    sk_pessoa            BIGSERIAL PRIMARY KEY,
    nk_id_pessoa         INTEGER NOT NULL,
    tipo_pessoa          INTEGER,
    nome                 VARCHAR(255),
    cpf_cnpj             VARCHAR(255),
    sexo                 VARCHAR(255),
    renda                DOUBLE PRECISION,
    estado_civil         VARCHAR(255),
    data_nascimento      DATE,

    -- Profissão
    id_profissao_origem  INTEGER,
    profissao            VARCHAR(255),

    -- Endereço desnormalizado
    id_endereco_origem   INTEGER,
    tipo_endereco        INTEGER,
    complemento          VARCHAR(255),
    endereco_preferencial BOOLEAN,
    logradouro           VARCHAR(255),
    tipo_logradouro      INTEGER,
    cep                  INTEGER,
    bairro               VARCHAR(255),
    regiao_cidade        VARCHAR(255),
    cidade               VARCHAR(255),
    uf                   VARCHAR(2),
    estado               VARCHAR(100),

    -- Controle dimensional
    data_atualizacao     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    inicio_validade      DATE NOT NULL DEFAULT CURRENT_DATE,
    fim_validade         DATE,
    registro_ativo       BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_d_pessoa_nk UNIQUE (nk_id_pessoa)
);

-- ============================================================
-- 4. DIMENSÃO PRODUTO
--    Categoria é incorporada à dimensão para manter a dimensão
--    desnormalizada, conforme o conceito de Star Schema.
-- ============================================================

CREATE TABLE mercearia_dw.d_produto (
    sk_produto            BIGSERIAL PRIMARY KEY,
    nk_id_produto         INTEGER NOT NULL,
    produto               VARCHAR(255) NOT NULL,
    valor_venda_atual     DOUBLE PRECISION NOT NULL,

    id_categoria_origem   INTEGER,
    categoria             VARCHAR(255),

    -- Controle dimensional
    data_atualizacao      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    inicio_validade       DATE NOT NULL DEFAULT CURRENT_DATE,
    fim_validade          DATE,
    registro_ativo        BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT uq_d_produto_nk UNIQUE (nk_id_produto)
);

-- ============================================================
-- 5. TABELA FATO VENDAS
--
-- Granularidade:
--   UMA LINHA PARA CADA ITEM DE UMA VENDA.
--
-- Exemplo:
--   Venda 10 possui 5 produtos diferentes
--   -> 5 linhas na F_VENDAS.
--
-- Medidas:
--   quantidade
--   valor_unitario
--   valor_total
-- ============================================================

CREATE TABLE mercearia_dw.f_vendas (
    sk_venda              BIGSERIAL PRIMARY KEY,

    -- Dimensões
    sk_tempo_venda        INTEGER NOT NULL,
    sk_tempo_faturamento  INTEGER,
    sk_produto             BIGINT NOT NULL,
    sk_cliente             BIGINT NOT NULL,

    -- Chaves de negócio / dimensões degeneradas
    id_venda_origem        INTEGER NOT NULL,
    id_item_venda_origem   INTEGER NOT NULL,
    tipo_venda             INTEGER NOT NULL,

    -- Medidas
    quantidade             INTEGER NOT NULL,
    valor_unitario         DOUBLE PRECISION NOT NULL,
    valor_total             DOUBLE PRECISION NOT NULL,

    CONSTRAINT fk_fv_tempo_venda
        FOREIGN KEY (sk_tempo_venda)
        REFERENCES mercearia_dw.d_tempo(sk_tempo),

    CONSTRAINT fk_fv_tempo_faturamento
        FOREIGN KEY (sk_tempo_faturamento)
        REFERENCES mercearia_dw.d_tempo(sk_tempo),

    CONSTRAINT fk_fv_produto
        FOREIGN KEY (sk_produto)
        REFERENCES mercearia_dw.d_produto(sk_produto),

    CONSTRAINT fk_fv_cliente
        FOREIGN KEY (sk_cliente)
        REFERENCES mercearia_dw.d_pessoa(sk_pessoa),

    CONSTRAINT uq_fv_item_origem
        UNIQUE (id_item_venda_origem)
);

-- ============================================================
-- 6. TABELA FATO COMPRAS
--
-- Granularidade:
--   UMA LINHA PARA CADA ITEM DE UMA COMPRA.
--
-- Medidas:
--   quantidade
--   valor_unitario
--   valor_total
-- ============================================================

CREATE TABLE mercearia_dw.f_compras (
    sk_compra             BIGSERIAL PRIMARY KEY,

    -- Dimensões
    sk_tempo_pedido       INTEGER NOT NULL,
    sk_tempo_entrada      INTEGER,
    sk_produto             BIGINT NOT NULL,
    sk_fornecedor          BIGINT NOT NULL,

    -- Chaves de negócio
    id_compra_origem       INTEGER NOT NULL,
    id_item_compra_origem  INTEGER NOT NULL,

    -- Medidas
    quantidade             INTEGER NOT NULL,
    valor_unitario         DOUBLE PRECISION NOT NULL,
    valor_total             DOUBLE PRECISION NOT NULL,

    CONSTRAINT fk_fc_tempo_pedido
        FOREIGN KEY (sk_tempo_pedido)
        REFERENCES mercearia_dw.d_tempo(sk_tempo),

    CONSTRAINT fk_fc_tempo_entrada
        FOREIGN KEY (sk_tempo_entrada)
        REFERENCES mercearia_dw.d_tempo(sk_tempo),

    CONSTRAINT fk_fc_produto
        FOREIGN KEY (sk_produto)
        REFERENCES mercearia_dw.d_produto(sk_produto),

    CONSTRAINT fk_fc_fornecedor
        FOREIGN KEY (sk_fornecedor)
        REFERENCES mercearia_dw.d_pessoa(sk_pessoa),

    CONSTRAINT uq_fc_item_origem
        UNIQUE (id_item_compra_origem)
);

-- ============================================================
-- 7. POPULAÇÃO DA DIMENSÃO TEMPO
--
-- A dimensão Tempo é criada com base no intervalo dos dados
-- existentes no OLTP.
-- ============================================================

INSERT INTO mercearia_dw.d_tempo (
    sk_tempo,
    data_completa,
    dia,
    nome_dia_semana,
    numero_dia_semana,
    semana_ano,
    mes,
    nome_mes,
    trimestre,
    semestre,
    ano,
    inicio_mes,
    fim_mes,
    fim_semana
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER AS sk_tempo,
    d::DATE,
    EXTRACT(DAY FROM d)::INTEGER,
    CASE EXTRACT(ISODOW FROM d)::INTEGER
        WHEN 1 THEN 'Segunda-feira'
        WHEN 2 THEN 'Terca-feira'
        WHEN 3 THEN 'Quarta-feira'
        WHEN 4 THEN 'Quinta-feira'
        WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sabado'
        WHEN 7 THEN 'Domingo'
    END,
    EXTRACT(ISODOW FROM d)::INTEGER,
    EXTRACT(WEEK FROM d)::INTEGER,
    EXTRACT(MONTH FROM d)::INTEGER,
    CASE EXTRACT(MONTH FROM d)::INTEGER
        WHEN 1 THEN 'Janeiro'
        WHEN 2 THEN 'Fevereiro'
        WHEN 3 THEN 'Marco'
        WHEN 4 THEN 'Abril'
        WHEN 5 THEN 'Maio'
        WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho'
        WHEN 8 THEN 'Agosto'
        WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro'
        WHEN 11 THEN 'Novembro'
        WHEN 12 THEN 'Dezembro'
    END,
    EXTRACT(QUARTER FROM d)::INTEGER,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END,
    EXTRACT(YEAR FROM d)::INTEGER,
    DATE_TRUNC('month', d)::DATE,
    (DATE_TRUNC('month', d) + INTERVAL '1 month - 1 day')::DATE,
    EXTRACT(ISODOW FROM d)::INTEGER IN (6,7)
FROM GENERATE_SERIES(
    LEAST(
        (SELECT MIN(DATA_VENDA) FROM public.Vendas),
        (SELECT MIN(DATA_PEDIDO) FROM public.Compras)
    ),
    GREATEST(
        (SELECT COALESCE(MAX(DATA_FATURAMENTO), MAX(DATA_VENDA)) FROM public.Vendas),
        (SELECT COALESCE(MAX(DATA_ENTRADA), MAX(DATA_PEDIDO)) FROM public.Compras)
    ),
    INTERVAL '1 day'
) AS s(d);

-- ============================================================
-- 8. CARGA DA DIMENSÃO PESSOA
--
-- A dimensão fica desnormalizada: profissão, logradouro,
-- bairro, cidade e UF são trazidos para uma única dimensão.
-- ============================================================

INSERT INTO mercearia_dw.d_pessoa (
    nk_id_pessoa,
    tipo_pessoa,
    nome,
    cpf_cnpj,
    sexo,
    renda,
    estado_civil,
    data_nascimento,
    id_profissao_origem,
    profissao,
    id_endereco_origem,
    tipo_endereco,
    complemento,
    endereco_preferencial,
    logradouro,
    tipo_logradouro,
    cep,
    bairro,
    regiao_cidade,
    cidade,
    uf,
    estado
)
SELECT
    p.ID_PESSOA,
    p.TIPO_PESSOA,
    p.NOME,
    p.CPF_CNPJ,
    p.SEXO,
    p.RENDA,
    p.ESTADO_CIVIL,
    p.DATA_NASCIMENTO,
    pr.ID_PROFISSAO,
    pr.NOME_PROFISSAO,
    e.ID_ENDERECO,
    e.TIPO_ENDERECO,
    e.COMPLEMENTO,
    e.PREFERENCIAL,
    l.LOGRADOURO,
    l.TIPO,
    l.CEP,
    b.NOME_BAIRRO,
    b.REGIAOCIDADE,
    c.NOME_CIDADE,
    u.SIGLA,
    u.NOME_ESTADO
FROM public.Pessoas p
LEFT JOIN public.Profissoes pr
    ON pr.ID_PROFISSAO = p.ID_PROFISSAO
LEFT JOIN public.Enderecos e
    ON e.ID_PESSOA = p.ID_PESSOA
   AND e.PREFERENCIAL = B'1'
LEFT JOIN public.Logradouros l
    ON l.ID_LOGRADOURO = e.ID_LOGRADOURO
LEFT JOIN public.Bairros b
    ON b.ID_BAIRRO = l.ID_BAIRRO
LEFT JOIN public.Cidades c
    ON c.ID_CIDADE = b.ID_CIDADE
LEFT JOIN public.Uf u
    ON u.ID_UF = c.ID_UF;

-- ============================================================
-- 9. CARGA DA DIMENSÃO PRODUTO
-- ============================================================

INSERT INTO mercearia_dw.d_produto (
    nk_id_produto,
    produto,
    valor_venda_atual,
    id_categoria_origem,
    categoria
)
SELECT
    p.ID_PRODUTO,
    p.PRODUTO,
    p.VALOR_VENDA,
    c.ID_CATEGORIA,
    c.NOME_CATEGORIA
FROM public.Produtos p
LEFT JOIN public.Categorias c
    ON c.ID_CATEGORIA = p.ID_CATEGORIA;

-- ============================================================
-- 10. CARGA DA FATO VENDAS
--
-- Fonte: Itens_Vendas + Vendas
-- Cada item é uma linha da fato.
-- ============================================================

INSERT INTO mercearia_dw.f_vendas (
    sk_tempo_venda,
    sk_tempo_faturamento,
    sk_produto,
    sk_cliente,
    id_venda_origem,
    id_item_venda_origem,
    tipo_venda,
    quantidade,
    valor_unitario,
    valor_total
)
SELECT
    tv.sk_tempo,
    tf.sk_tempo,
    dp.sk_produto,
    dcli.sk_pessoa,
    v.ID_VENDA,
    iv.ID_ITEMVENDA,
    v.TIPO_VENDA,
    iv.QUANTIDADE,
    iv.VLR_UNITARIO,
    iv.QUANTIDADE * iv.VLR_UNITARIO
FROM public.Itens_Vendas iv
INNER JOIN public.Vendas v
    ON v.ID_VENDA = iv.ID_VENDA
INNER JOIN mercearia_dw.d_tempo tv
    ON tv.data_completa = v.DATA_VENDA
LEFT JOIN mercearia_dw.d_tempo tf
    ON tf.data_completa = v.DATA_FATURAMENTO
INNER JOIN mercearia_dw.d_produto dp
    ON dp.nk_id_produto = iv.ID_PRODUTO
INNER JOIN mercearia_dw.d_pessoa dcli
    ON dcli.nk_id_pessoa = v.ID_PESSOA;

-- ============================================================
-- 11. CARGA DA FATO COMPRAS
--
-- Fonte: Itens_compras + Compras
-- Cada item é uma linha da fato.
-- ============================================================

INSERT INTO mercearia_dw.f_compras (
    sk_tempo_pedido,
    sk_tempo_entrada,
    sk_produto,
    sk_fornecedor,
    id_compra_origem,
    id_item_compra_origem,
    quantidade,
    valor_unitario,
    valor_total
)
SELECT
    tp.sk_tempo,
    te.sk_tempo,
    dp.sk_produto,
    dfor.sk_pessoa,
    c.ID_COMPRA,
    ic.ID_ITEMCOMPRA,
    ic.QUANTIDADE,
    ic.VLR_UNITARIO,
    ic.QUANTIDADE * ic.VLR_UNITARIO
FROM public.Itens_compras ic
INNER JOIN public.Compras c
    ON c.ID_COMPRA = ic.ID_COMPRA
INNER JOIN mercearia_dw.d_tempo tp
    ON tp.data_completa = c.DATA_PEDIDO
LEFT JOIN mercearia_dw.d_tempo te
    ON te.data_completa = c.DATA_ENTRADA
INNER JOIN mercearia_dw.d_produto dp
    ON dp.nk_id_produto = ic.ID_PRODUTO
INNER JOIN mercearia_dw.d_pessoa dfor
    ON dfor.nk_id_pessoa = c.ID_PESSOA;

-- ============================================================
-- 12. ÍNDICES PARA CONSULTAS ANALÍTICAS
-- ============================================================

CREATE INDEX idx_f_vendas_tempo
    ON mercearia_dw.f_vendas(sk_tempo_venda);

CREATE INDEX idx_f_vendas_produto
    ON mercearia_dw.f_vendas(sk_produto);

CREATE INDEX idx_f_vendas_cliente
    ON mercearia_dw.f_vendas(sk_cliente);

CREATE INDEX idx_f_compras_tempo
    ON mercearia_dw.f_compras(sk_tempo_pedido);

CREATE INDEX idx_f_compras_produto
    ON mercearia_dw.f_compras(sk_produto);

CREATE INDEX idx_f_compras_fornecedor
    ON mercearia_dw.f_compras(sk_fornecedor);

CREATE INDEX idx_d_produto_categoria
    ON mercearia_dw.d_produto(categoria);

CREATE INDEX idx_d_pessoa_cidade
    ON mercearia_dw.d_pessoa(cidade);

CREATE INDEX idx_d_pessoa_bairro
    ON mercearia_dw.d_pessoa(bairro);

-- ============================================================
-- 13. VIEWS ANALÍTICAS PARA BI
-- ============================================================

CREATE OR REPLACE VIEW mercearia_dw.v_vendas_analitico AS
SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    t.trimestre,
    t.data_completa,
    p.produto,
    p.categoria,
    cli.nome AS cliente,
    cli.sexo,
    cli.estado_civil,
    cli.profissao,
    cli.bairro,
    cli.cidade,
    cli.uf,
    f.tipo_venda,
    f.quantidade,
    f.valor_unitario,
    f.valor_total
FROM mercearia_dw.f_vendas f
INNER JOIN mercearia_dw.d_tempo t
    ON t.sk_tempo = f.sk_tempo_venda
INNER JOIN mercearia_dw.d_produto p
    ON p.sk_produto = f.sk_produto
INNER JOIN mercearia_dw.d_pessoa cli
    ON cli.sk_pessoa = f.sk_cliente;

CREATE OR REPLACE VIEW mercearia_dw.v_compras_analitico AS
SELECT
    t.ano,
    t.mes,
    t.nome_mes,
    t.trimestre,
    t.data_completa,
    p.produto,
    p.categoria,
    forn.nome AS fornecedor,
    forn.cidade,
    forn.uf,
    f.quantidade,
    f.valor_unitario,
    f.valor_total
FROM mercearia_dw.f_compras f
INNER JOIN mercearia_dw.d_tempo t
    ON t.sk_tempo = f.sk_tempo_pedido
INNER JOIN mercearia_dw.d_produto p
    ON p.sk_produto = f.sk_produto
INNER JOIN mercearia_dw.d_pessoa forn
    ON forn.sk_pessoa = f.sk_fornecedor;

-- ============================================================
-- 14. CONSULTAS DE VALIDAÇÃO
-- ============================================================

-- Quantidade de registros:
-- SELECT COUNT(*) FROM mercearia_dw.d_tempo;
-- SELECT COUNT(*) FROM mercearia_dw.d_pessoa;
-- SELECT COUNT(*) FROM mercearia_dw.d_produto;
-- SELECT COUNT(*) FROM mercearia_dw.f_vendas;
-- SELECT COUNT(*) FROM mercearia_dw.f_compras;

-- Faturamento por mês:
-- SELECT ano, mes, nome_mes, SUM(valor_total) AS faturamento
-- FROM mercearia_dw.v_vendas_analitico
-- GROUP BY ano, mes, nome_mes
-- ORDER BY ano, mes;

-- Faturamento por categoria:
-- SELECT categoria, SUM(valor_total) AS faturamento
-- FROM mercearia_dw.v_vendas_analitico
-- GROUP BY categoria
-- ORDER BY faturamento DESC;

-- Faturamento por cidade:
-- SELECT cidade, uf, SUM(valor_total) AS faturamento
-- FROM mercearia_dw.v_vendas_analitico
-- GROUP BY cidade, uf
-- ORDER BY faturamento DESC;

-- Produtos mais vendidos:
-- SELECT produto, SUM(quantidade) AS quantidade_vendida,
--        SUM(valor_total) AS faturamento
-- FROM mercearia_dw.v_vendas_analitico
-- GROUP BY produto
-- ORDER BY quantidade_vendida DESC;

-- Compras por categoria:
-- SELECT categoria, SUM(valor_total) AS valor_comprado
-- FROM mercearia_dw.v_compras_analitico
-- GROUP BY categoria
-- ORDER BY valor_comprado DESC;

-- ============================================================
-- FIM DO DATA WAREHOUSE
-- ============================================================
