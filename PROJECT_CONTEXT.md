# \# InsureGPTE™ Project Context

# Version: 2.0

# Status: Active Development

# Target Launch: Version 1.0

# 

# \---

# 

# \# Project Vision

# 

# InsureGPTE is a commercial AI-powered Insurance Learning, Examination and Assessment Platform designed for insurance professionals, students, brokers, surveyors and corporate learners.

# 

# The platform focuses on structured learning, examination preparation, progress tracking and AI-assisted education.

# 

# This project is NOT a CRM, policy administration system, claims management system or recruitment portal.

# 

# \---

# 

# \# Technology Stack

# 

# Frontend

# \- HTML5

# \- Tailwind CSS

# \- JavaScript (Vanilla)

# 

# Backend

# \- Supabase

# \- PostgreSQL

# \- Supabase Auth

# \- Supabase Storage

# 

# Hosting

# \- Vercel

# 

# Version Control

# \- GitHub

# 

# AI

# \- OpenAI

# \- ChatGPT Codex (Primary Development Assistant)

# 

# Email

# \- Namecheap Private Email

# \- SMTP Enabled

# 

# \---

# 

# \# Development Philosophy

# 

# Database First

# 

# ↓

# 

# RPC Layer

# 

# ↓

# 

# Frontend

# 

# ↓

# 

# Testing

# 

# ↓

# 

# Deployment

# 

# Frontend must NEVER access database tables directly.

# 

# Frontend communicates only through RPCs.

# 

# \---

# 

# \# Current Database Status

# 

# Approximately 95% Complete

# 

# Major Modules

# 

# ✓ Authentication

# 

# ✓ Profiles

# 

# ✓ Qualification Levels

# 

# ✓ Exam Authorities

# 

# ✓ Training Programmes

# 

# ✓ Programme Sections

# 

# ✓ Subjects

# 

# ✓ Subject Modules

# 

# ✓ Subject Chapters

# 

# ✓ Subject Topics

# 

# ✓ Learning Resource Types

# 

# ✓ Learning Resources

# 

# ✓ Flashcards

# 

# ✓ Questions

# 

# ✓ Quiz Engine

# 

# ✓ Quiz Attempts

# 

# ✓ User Progress

# 

# ✓ Learning Activity

# 

# ✓ Cart

# 

# ✓ Cart Items

# 

# ✓ User Entitlements

# 

# \---

# 

# \# Authentication

# 

# Supabase Email Authentication

# 

# Email Verification Enabled

# 

# Account Status

# 

# \- verification\_pending

# \- active

# \- suspended

# \- closed

# 

# \---

# 

# \# Default User Values

# 

# role = user

# 

# subscription\_plan = free

# 

# status = verification\_pending

# 

# \---

# 

# \# Academic Hierarchy

# 

# Qualification Level

# 

# ↓

# 

# Exam Authority

# 

# ↓

# 

# Training Programme

# 

# ↓

# 

# Programme Section

# 

# ↓

# 

# Subject

# 

# ↓

# 

# Module

# 

# ↓

# 

# Chapter

# 

# ↓

# 

# Topic

# 

# \---

# 

# \# Learning Engine

# 

# Learning Resources

# 

# Flashcards

# 

# Revision Notes

# 

# AI Notes

# 

# PDF

# 

# Videos

# 

# External Links

# 

# Progress Tracking

# 

# Learning Activity

# 

# \---

# 

# \# Quiz Engine

# 

# Current Status

# 

# Operational

# 

# Existing RPCs

# 

# \- start\_quiz\_attempt()

# 

# \- get\_attempt\_questions()

# 

# \- submit\_quiz\_answer()

# 

# \- evaluate\_quiz\_answer()

# 

# \- finalize\_quiz\_attempt()

# 

# \- finalize\_quiz\_attempt\_with\_answers()

# 

# \- get\_my\_quiz\_attempts()

# 

# \---

# 

# \# Commerce

# 

# Cart

# 

# Cart Items

# 

# User Entitlements

# 

# Subscription Plans

# 

# Free

# 

# Paid

# 

# Premium

# 

# Enterprise

# 

# \---

# 

# \# Security Rules

# 

# Frontend never updates

# 

# \- role

# 

# \- status

# 

# \- subscription\_plan

# 

# \- user\_id

# 

# All business logic must execute through RPCs.

# 

# \---

# 

# \# Folder Structure

# 

# DATABASE/

# 

# SQL/

# 

# RPC/

# 

# FRONTEND/

# 

# SUPABASE/

# 

# DOCUMENTS/

# 

# TESTING/

# 

# API/

# 

# \---

# 

# \# Current Development Phase

# 

# Phase 2

# 

# RPC Layer Development

# 

# \---

# 

# \# Immediate Objectives

# 

# 1\. Complete remaining RPCs

# 

# 2\. Dashboard APIs

# 

# 3\. Analytics APIs

# 

# 4\. Learning APIs

# 

# 5\. Recommendation Engine

# 

# 6\. Frontend Integration

# 

# 7\. End-to-End Testing

# 

# 8\. Production Deployment

# 

# \---

# 

# \# Coding Standards

# 

# CREATE OR REPLACE FUNCTION

# 

# SECURITY DEFINER

# 

# auth.uid() validation

# 

# Proper error handling

# 

# GRANT EXECUTE

# 

# Version controlled SQL

# 

# \---

# 

# \# Repository Rules

# 

# GitHub is the single source of truth.

# 

# All SQL changes are committed before deployment.

# 

# No direct production edits.

# 

# Every feature must include:

# 

# \- SQL

# \- RPC

# \- Frontend Integration

# \- Testing

# 

# \---

# 

# \# Current Development Assistant

# 

# Primary Coding Assistant

# 

# ChatGPT Codex

# 

# Architecture \& Product Design

# 

# ChatGPT

