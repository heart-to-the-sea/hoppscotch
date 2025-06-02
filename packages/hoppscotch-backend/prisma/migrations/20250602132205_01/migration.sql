-- DropIndex
DROP INDEX "TeamCollection_title_trgm_idx";

-- DropIndex
DROP INDEX "TeamRequest_title_trgm_idx";

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "password" TEXT,
ADD COLUMN     "username" TEXT;

-- CreateTable
CREATE TABLE "LocalDomain" (
    "id" TEXT NOT NULL,
    "daemon" TEXT,

    CONSTRAINT "LocalDomain_pkey" PRIMARY KEY ("id")
);
