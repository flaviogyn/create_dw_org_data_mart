-- ================================================================
-- DW ORGANIZACIONAL - MERCEARIA
-- Modelo dimensional: Star Schema
-- Granularidade das fatos: 1 linha por produto em cada transacao
-- Historico: SCD Tipo 2 nas dimensoes principais
-- ================================================================

CREATE SCHEMA IF NOT EXISTS dw_mercearia;

-- ---------------------------------------------------------------
-- Dimensao Tempo
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.dim_tempo (
    sk_tempo            INTEGER PRIMARY KEY,
    data_calendario     DATE NOT NULL UNIQUE,
    dia                 SMALLINT NOT NULL,
    dia_semana          SMALLINT NOT NULL,
    nome_dia_semana     VARCHAR(15) NOT NULL,
    semana_ano          SMALLINT NOT NULL,
    mes                 SMALLINT NOT NULL,
    nome_mes            VARCHAR(15) NOT NULL,
    trimestre            SMALLINT NOT NULL,
    semestre             SMALLINT NOT NULL,
    ano                  SMALLINT NOT NULL,
    fim_de_semana       BOOLEAN NOT NULL,
    feriado             BOOLEAN NOT NULL DEFAULT FALSE
);

-- ---------------------------------------------------------------
-- Dimensao Pessoa/Cliente
-- Origem: Pessoas + Enderecos + Logradouros + Bairros + Cidades + UF
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.dim_cliente (
    sk_cliente          BIGSERIAL PRIMARY KEY,
    nk_cliente          INTEGER NOT NULL,
    tipo_pessoa         INTEGER,
    nome_cliente        VARCHAR(255),
    cpf_cnpj            VARCHAR(255),
    sexo                VARCHAR(50),
    renda               NUMERIC(18,2),
    estado_civil        VARCHAR(100),
    data_nascimento     DATE,
    profissao           VARCHAR(100),
    tipo_endereco       INTEGER,
    complemento         VARCHAR(255),
    logradouro          VARCHAR(255),
    numero_inicial      INTEGER,
    numero_final        INTEGER,
    cep                 VARCHAR(20),
    bairro              VARCHAR(255),
    regiao_cidade       VARCHAR(255),
    cidade              VARCHAR(255),
    uf                  VARCHAR(100),
    sigla_uf            VARCHAR(2),
    telefone            VARCHAR(255),
    ddd                 VARCHAR(5),
    status_telefone     VARCHAR(1),
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'MERCEARIA',
    CONSTRAINT uk_dim_cliente_hist UNIQUE (nk_cliente, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Produto
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.dim_produto (
    sk_produto          BIGSERIAL PRIMARY KEY,
    nk_produto          INTEGER NOT NULL,
    produto             VARCHAR(255) NOT NULL,
    sk_categoria        BIGINT,
    categoria           VARCHAR(255),
    valor_venda_atual   NUMERIC(18,2),
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'MERCEARIA',
    CONSTRAINT uk_dim_produto_hist UNIQUE (nk_produto, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Fornecedor
-- Na Mercearia, Pessoas pode representar a contraparte da compra.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.dim_fornecedor (
    sk_fornecedor       BIGSERIAL PRIMARY KEY,
    nk_fornecedor       INTEGER NOT NULL,
    nome_fornecedor     VARCHAR(255),
    cpf_cnpj             VARCHAR(255),
    cidade              VARCHAR(255),
    uf                  VARCHAR(100),
    sigla_uf            VARCHAR(2),
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'MERCEARIA',
    CONSTRAINT uk_dim_fornecedor_hist UNIQUE (nk_fornecedor, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Localizacao
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.dim_localizacao (
    sk_localizacao      BIGSERIAL PRIMARY KEY,
    nk_endereco         INTEGER NOT NULL,
    logradouro          VARCHAR(255),
    numero_inicial      INTEGER,
    numero_final        INTEGER,
    cep                 VARCHAR(20),
    bairro              VARCHAR(255),
    regiao_cidade       VARCHAR(255),
    cidade              VARCHAR(255),
    uf                  VARCHAR(100),
    sigla_uf            VARCHAR(2),
    pais                VARCHAR(100) DEFAULT 'Brasil',
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'MERCEARIA',
    CONSTRAINT uk_dim_localizacao_hist UNIQUE (nk_endereco, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Fonte de Dados / Dados Externos
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.dim_fonte_dado (
    sk_fonte            BIGSERIAL PRIMARY KEY,
    sistema_origem      VARCHAR(100) NOT NULL,
    tabela_origem       VARCHAR(100),
    tipo_fonte          VARCHAR(50) NOT NULL,
    descricao           VARCHAR(255),
    data_carga          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------
-- Fato Vendas
-- Granularidade: um produto em uma venda.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.fato_vendas (
    sk_venda            BIGSERIAL PRIMARY KEY,
    nk_venda            INTEGER NOT NULL,
    sk_tempo            INTEGER NOT NULL REFERENCES dw_mercearia.dim_tempo(sk_tempo),
    sk_cliente          BIGINT NOT NULL REFERENCES dw_mercearia.dim_cliente(sk_cliente),
    sk_produto          BIGINT NOT NULL REFERENCES dw_mercearia.dim_produto(sk_produto),
    sk_localizacao      BIGINT REFERENCES dw_mercearia.dim_localizacao(sk_localizacao),
    sk_fonte             BIGINT REFERENCES dw_mercearia.dim_fonte_dado(sk_fonte),
    tipo_venda          INTEGER,
    data_faturamento    DATE,
    quantidade          NUMERIC(18,3) NOT NULL,
    valor_unitario      NUMERIC(18,2) NOT NULL,
    valor_bruto         NUMERIC(18,2) NOT NULL,
    valor_desconto      NUMERIC(18,2) NOT NULL DEFAULT 0,
    valor_liquido       NUMERIC(18,2) NOT NULL,
    CONSTRAINT uk_fato_vendas_origem UNIQUE (nk_venda, sk_produto)
);

-- ---------------------------------------------------------------
-- Fato Compras
-- Granularidade: um produto em uma compra.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_mercearia.fato_compras (
    sk_compra           BIGSERIAL PRIMARY KEY,
    nk_compra           INTEGER NOT NULL,
    sk_tempo            INTEGER NOT NULL REFERENCES dw_mercearia.dim_tempo(sk_tempo),
    sk_fornecedor       BIGINT NOT NULL REFERENCES dw_mercearia.dim_fornecedor(sk_fornecedor),
    sk_produto          BIGINT NOT NULL REFERENCES dw_mercearia.dim_produto(sk_produto),
    sk_fonte             BIGINT REFERENCES dw_mercearia.dim_fonte_dado(sk_fonte),
    data_entrada        DATE,
    quantidade          NUMERIC(18,3) NOT NULL,
    valor_unitario      NUMERIC(18,2) NOT NULL,
    valor_total         NUMERIC(18,2) NOT NULL,
    CONSTRAINT uk_fato_compras_origem UNIQUE (nk_compra, sk_produto)
);

-- Indices para consultas analiticas
CREATE INDEX IF NOT EXISTS ix_fato_vendas_tempo ON dw_mercearia.fato_vendas(sk_tempo);
CREATE INDEX IF NOT EXISTS ix_fato_vendas_cliente ON dw_mercearia.fato_vendas(sk_cliente);
CREATE INDEX IF NOT EXISTS ix_fato_vendas_produto ON dw_mercearia.fato_vendas(sk_produto);
CREATE INDEX IF NOT EXISTS ix_fato_compras_tempo ON dw_mercearia.fato_compras(sk_tempo);
CREATE INDEX IF NOT EXISTS ix_fato_compras_fornecedor ON dw_mercearia.fato_compras(sk_fornecedor);
CREATE INDEX IF NOT EXISTS ix_fato_compras_produto ON dw_mercearia.fato_compras(sk_produto);
