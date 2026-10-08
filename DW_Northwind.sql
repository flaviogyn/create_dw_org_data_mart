-- ================================================================
-- DW ORGANIZACIONAL - NORTHWIND
-- Mesmo padrao dimensional utilizado no DW da Mercearia
-- Modelo: Star Schema
-- Granularidade de vendas: 1 linha por produto em cada pedido
-- Historico: SCD Tipo 2 nas dimensoes principais
-- ================================================================

CREATE SCHEMA IF NOT EXISTS dw_northwind;

-- ---------------------------------------------------------------
-- Dimensao Tempo
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_tempo (
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
-- Dimensao Cliente
-- Origem: customers + customer_demographics + customer_customer_demo
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_cliente (
    sk_cliente          BIGSERIAL PRIMARY KEY,
    nk_cliente          VARCHAR(5) NOT NULL,
    empresa             VARCHAR(40) NOT NULL,
    nome_contato        VARCHAR(30),
    cargo_contato       VARCHAR(30),
    endereco            VARCHAR(60),
    cidade              VARCHAR(15),
    regiao              VARCHAR(15),
    codigo_postal       VARCHAR(10),
    pais                VARCHAR(15),
    telefone            VARCHAR(24),
    fax                 VARCHAR(24),
    tipo_cliente        VARCHAR(255),
    descricao_tipo      TEXT,
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'NORTHWIND',
    CONSTRAINT uk_dim_cliente_hist UNIQUE (nk_cliente, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Produto
-- Origem: products + categories
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_produto (
    sk_produto          BIGSERIAL PRIMARY KEY,
    nk_produto          SMALLINT NOT NULL,
    produto             VARCHAR(40) NOT NULL,
    nk_fornecedor       SMALLINT,
    sk_categoria        BIGINT,
    categoria           VARCHAR(15),
    descricao_categoria TEXT,
    quantidade_por_unidade VARCHAR(20),
    valor_unitario_atual NUMERIC(18,2),
    unidades_estoque    INTEGER,
    unidades_pedido     INTEGER,
    nivel_reposicao     INTEGER,
    descontinuado       BOOLEAN NOT NULL DEFAULT FALSE,
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'NORTHWIND',
    CONSTRAINT uk_dim_produto_hist UNIQUE (nk_produto, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Fornecedor
-- Origem: suppliers
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_fornecedor (
    sk_fornecedor       BIGSERIAL PRIMARY KEY,
    nk_fornecedor       SMALLINT NOT NULL,
    empresa             VARCHAR(40) NOT NULL,
    nome_contato        VARCHAR(30),
    cargo_contato       VARCHAR(30),
    endereco            VARCHAR(60),
    cidade              VARCHAR(15),
    regiao              VARCHAR(15),
    codigo_postal       VARCHAR(10),
    pais                VARCHAR(15),
    telefone            VARCHAR(24),
    fax                 VARCHAR(24),
    homepage            TEXT,
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'NORTHWIND',
    CONSTRAINT uk_dim_fornecedor_hist UNIQUE (nk_fornecedor, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Funcionario/Vendedor
-- Origem: employees + employee_territories + territories + region
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_vendedor (
    sk_vendedor         BIGSERIAL PRIMARY KEY,
    nk_vendedor         SMALLINT NOT NULL,
    nome_completo       VARCHAR(100) NOT NULL,
    sobrenome           VARCHAR(20),
    nome                VARCHAR(10),
    cargo               VARCHAR(30),
    tratamento          VARCHAR(25),
    data_nascimento     DATE,
    data_contratacao    DATE,
    cidade              VARCHAR(15),
    regiao              VARCHAR(15),
    codigo_postal       VARCHAR(10),
    pais                VARCHAR(15),
    telefone            VARCHAR(24),
    extensao            VARCHAR(4),
    nk_gerente          SMALLINT,
    territorio          VARCHAR(20),
    descricao_territorio VARCHAR(60),
    regiao_territorio   VARCHAR(60),
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'NORTHWIND',
    CONSTRAINT uk_dim_vendedor_hist UNIQUE (nk_vendedor, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Transportadora
-- Origem: shippers
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_transportadora (
    sk_transportadora   BIGSERIAL PRIMARY KEY,
    nk_transportadora   SMALLINT NOT NULL,
    empresa             VARCHAR(40) NOT NULL,
    telefone            VARCHAR(24),
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'NORTHWIND',
    CONSTRAINT uk_dim_transportadora_hist UNIQUE (nk_transportadora, data_inicio)
);

-- ---------------------------------------------------------------
-- Dimensao Localizacao
-- Mantem o endereco de entrega do pedido como dimensao analitica.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_localizacao (
    sk_localizacao      BIGSERIAL PRIMARY KEY,
    endereco            VARCHAR(60),
    cidade              VARCHAR(15),
    regiao              VARCHAR(15),
    codigo_postal       VARCHAR(10),
    pais                VARCHAR(15),
    data_inicio         DATE NOT NULL DEFAULT CURRENT_DATE,
    data_fim            DATE NOT NULL DEFAULT DATE '9999-12-31',
    registro_atual      BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_dado          VARCHAR(50) NOT NULL DEFAULT 'NORTHWIND'
);

-- ---------------------------------------------------------------
-- Dimensao Fonte de Dados / Dados Externos
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.dim_fonte_dado (
    sk_fonte            BIGSERIAL PRIMARY KEY,
    sistema_origem      VARCHAR(100) NOT NULL,
    tabela_origem       VARCHAR(100),
    tipo_fonte          VARCHAR(50) NOT NULL,
    descricao           VARCHAR(255),
    data_carga          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------
-- Fato Vendas
-- Granularidade: um produto em cada pedido.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dw_northwind.fato_vendas (
    sk_venda            BIGSERIAL PRIMARY KEY,
    nk_pedido           SMALLINT NOT NULL,
    sk_tempo            INTEGER NOT NULL REFERENCES dw_northwind.dim_tempo(sk_tempo),
    sk_cliente          BIGINT NOT NULL REFERENCES dw_northwind.dim_cliente(sk_cliente),
    sk_produto          BIGINT NOT NULL REFERENCES dw_northwind.dim_produto(sk_produto),
    sk_vendedor         BIGINT REFERENCES dw_northwind.dim_vendedor(sk_vendedor),
    sk_transportadora   BIGINT REFERENCES dw_northwind.dim_transportadora(sk_transportadora),
    sk_localizacao      BIGINT REFERENCES dw_northwind.dim_localizacao(sk_localizacao),
    sk_fonte             BIGINT REFERENCES dw_northwind.dim_fonte_dado(sk_fonte),
    data_pedido         DATE,
    data_entrega_prevista DATE,
    data_envio          DATE,
    quantidade          NUMERIC(18,3) NOT NULL,
    valor_unitario      NUMERIC(18,2) NOT NULL,
    percentual_desconto NUMERIC(9,6) NOT NULL DEFAULT 0,
    valor_bruto         NUMERIC(18,2) NOT NULL,
    valor_desconto      NUMERIC(18,2) NOT NULL DEFAULT 0,
    valor_liquido       NUMERIC(18,2) NOT NULL,
    frete_rateado       NUMERIC(18,2) DEFAULT 0,
    CONSTRAINT uk_fato_vendas_origem UNIQUE (nk_pedido, sk_produto)
);

-- ---------------------------------------------------------------
-- Observacao sobre compras:
-- O DDL Northwind fornecido nao possui uma tabela transacional de
-- compras/recebimento de mercadorias. Portanto, nao foi criada uma
-- FATO_COMPRAS ficticia. Os fornecedores sao mantidos como dimensao.
-- ---------------------------------------------------------------

CREATE INDEX IF NOT EXISTS ix_fato_vendas_tempo ON dw_northwind.fato_vendas(sk_tempo);
CREATE INDEX IF NOT EXISTS ix_fato_vendas_cliente ON dw_northwind.fato_vendas(sk_cliente);
CREATE INDEX IF NOT EXISTS ix_fato_vendas_produto ON dw_northwind.fato_vendas(sk_produto);
CREATE INDEX IF NOT EXISTS ix_fato_vendas_vendedor ON dw_northwind.fato_vendas(sk_vendedor);
CREATE INDEX IF NOT EXISTS ix_fato_vendas_transportadora ON dw_northwind.fato_vendas(sk_transportadora);
